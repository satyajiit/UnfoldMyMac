import AppKit
import Observation
import UnfoldMyMacCore

/// Runs the effect on the built-in display: polls or reads the lid, applies the display gate, starts and stops
/// the session, drives frames from the display link and owns the preview clock. Every observable property is
/// written only when its value changes, so a steady state produces no invalidations (P7).
@MainActor @Observable final class EffectRuntime: ChangeGuardedPublishing {
    private(set) var status: EffectRuntimeStatus = .off
    private(set) var enabled = false
    private(set) var lidAngle: Double?
    private(set) var sensorAvailable = false
    private(set) var diagnostic = LidMonitor.initialDiagnostic
    private(set) var displayName = DisplayGate.unavailableName
    private(set) var captureFrames = 0
    private(set) var gpuMilliseconds = 0.0
    private(set) var isPreviewing = false
    private(set) var isPlaying = false
    private(set) var previewEffectID: EffectID?
    private(set) var previewClosure = 0.0
    private(set) var reduceTransparency = false
    private(set) var reduceMotion = false

    @ObservationIgnored let session: EffectSession
    @ObservationIgnored private let registry: EffectRegistry
    @ObservationIgnored private let preferences: EffectPreferences
    @ObservationIgnored private let systemState: SystemStateSubscriber
    @ObservationIgnored private let clock: () -> TimeInterval
    @ObservationIgnored private let lid: LidMonitor
    @ObservationIgnored private var gate: DisplayGate
    @ObservationIgnored let pacing = EffectPacing()
    @ObservationIgnored private var preview = PreviewController()
    @ObservationIgnored private var started = false
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var angleObserved = false
    @ObservationIgnored private var animationSeconds = 0.0
    @ObservationIgnored private var lastTelemetry = -Double.infinity

    init(session: EffectSession, registry: EffectRegistry, preferences: EffectPreferences, environment: any SystemEnvironmentObserving,
         displays: any DisplayProviding, makeSensor: @escaping () -> any LidReading, clock: @escaping () -> TimeInterval) {
        self.session = session; self.registry = registry; self.preferences = preferences; self.clock = clock
        systemState = SystemStateSubscriber(environment: environment)
        lid = LidMonitor(makeSensor: makeSensor); gate = DisplayGate(displays: displays)
    }
    var activeEffect: EffectDescriptor { registry.entry(for: preview.effectID ?? preferences.settings.effect).descriptor }

    func start() {
        started = true
        pacing.onTick = { [weak self] in self?.tick() }
        pacing.onFrame = { [weak self] delta in self?.renderFrame(deltaTime: delta) }
        systemState.start { [weak self] event in self?.systemStateChanged(event) }
        applyPolling(); tick()
    }
    func shutdown() {
        started = false
        pacing.stop(); session.stop(); systemState.stop()
    }
    /// During a preview the choice is remembered and applies once the preview ends (L1).
    func setEnabled(_ value: Bool) {
        if preview.isPreviewing {
            preview.rememberEnabled(value)
            guard !value else { return }
            stopPreview()
        }
        publish(\.enabled, value)
        if value { gate.reset(); applyPolling(); tick() }
        else { session.stop(); pacing.stopLink(); publish(\.status, .off); applyPolling() }
    }
    /// The chosen effect changed: nothing of the old one is reusable.
    func effectChanged() { session.stop(); animationSeconds = 0; tick() }
    /// The angle is on screen somewhere other than the menu bar, so idle polling keeps it current.
    func setAngleObserved(_ value: Bool) { angleObserved = value; applyPolling(); if value { tick() } }
    func refreshPolling() { applyPolling() }

    // MARK: Preview

    /// Returns whether a preview began or switched, so the caller can bring the library forward.
    @discardableResult func beginPreview(effect id: EffectID?) -> Bool {
        let transition = preview.begin(effect: registry.entry(for: id ?? preferences.settings.effect).descriptor.id, enabled: enabled)
        guard transition != .unchanged else { return false }
        if transition == .started { session.suspend() } else { session.stop(retaining: true) }
        pacing.stopLink()
        publish(\.enabled, true); animationSeconds = 0
        gate.reset(); publishPreview(); applyPolling(); tick()
        return true
    }
    func playPreview() {
        guard !reduceMotion else { return }
        if !preview.isPreviewing { beginPreview(effect: nil) }
        preview.play(); publishPreview()
    }
    func pausePreview() { preview.pause(); publishPreview() }
    func scrubPreview(_ value: Double) { preview.scrub(value); publishPreview() }
    func stopPreview() {
        guard preview.isPreviewing else { return }
        endPreview(restoring: .previous)
    }
    /// A failed chosen effect turns effects off; a failed card preview only ends the preview (P16).
    @discardableResult func effectFailed(needsPermission: Bool) -> Bool {
        let chosenFailed = !preview.isPreviewing || preview.effectID == preferences.settings.effect
        if preview.isPreviewing { endPreview(restoring: chosenFailed ? .disabled : .previous) }
        guard chosenFailed else { return false }
        publish(\.enabled, false); session.stop(); pacing.stopLink()
        publish(\.status, needsPermission ? .screenRecordingNeeded : .unavailable); applyPolling()
        return true
    }
    private func endPreview(restoring restore: PreviewController.Restore) {
        publish(\.enabled, preview.end(restoring: restore))
        session.stop(retaining: true); pacing.stopLink(); gate.reset(); animationSeconds = 0
        publishPreview(); publish(\.status, enabled ? .ready : .off)
        applyPolling(); tick()
    }

    // MARK: Clocks

    func tick() {
        let now = clock()
        // Live rendering reads immediately before each frame; poll only while idle or previewing.
        if !pacing.isLinked || preview.isPreviewing { readLid(now: now) }
        publish(\.displayName, gate.screenName)
        if now - lastTelemetry >= EffectTuning.telemetryInterval { lastTelemetry = now; publishTelemetry() }
        guard enabled, !suspended, case .ready(let screen) = evaluateGate(now: now) else { return }
        session.start(effect: activeEffect.id, screen: screen, reduceTransparency: reduceTransparency)
        guard enabled else { return } // A synchronous start failure has already turned effects off.
        pacing.startLink(on: screen)
        publish(\.status, .rendering(ready: session.renderer?.ready == true, previewing: preview.isPreviewing, lidAngle: lidAngle,
                                     activation: preferences.settings.activation, rendered: session.renderedEffect ?? activeEffect.id, requested: activeEffect.id))
    }
    func renderFrame(deltaTime: TimeInterval) {
        guard enabled, !suspended, gate.isReady, session.renderer != nil else { return }
        let delta = (deltaTime.isFinite ? deltaTime : 0).clamped(to: EffectTuning.frameDeltaRange)
        let progress: Double
        if preview.isPreviewing {
            preview.advance(by: delta); publishPreview()
            progress = EffectMath.calibratedClosure(preview.closure, completionFraction: preferences.settings.completionFraction)
        } else {
            readLid(now: clock())
            guard sensorAvailable, let lidAngle, lidAngle > EffectMath.closedLid else {
                _ = evaluateGate(now: clock()) // Sensor loss and a physically closed lid stop this frame, never restart the link.
                return
            }
            progress = EffectMath.liveProgress(lid: lidAngle, activation: preferences.settings.activation, completionFraction: preferences.settings.completionFraction)
        }
        // No temporal filter: a fresh angle or a scrub position controls this frame directly.
        if progress > 0, !reduceMotion, !preview.isPreviewing || preview.isPlaying { animationSeconds += delta }
        session.update(.init(closure: progress, parameters: preferences.settings.parameters(for: activeEffect.id), reduceTransparency: reduceTransparency,
            time: session.renderer?.animatesWithTime == true ? animationSeconds : 0, reduceMotion: reduceMotion))
    }
    /// A blocked verdict tears the effect down at once; only `tick` brings it back.
    private func evaluateGate(now: TimeInterval) -> DisplayGate.Verdict {
        let verdict = gate.evaluate(lidAngle: lidAngle, sensorAvailable: sensorAvailable, previewing: preview.isPreviewing, now: now)
        if case .blocked(let state) = verdict { session.stop(retaining: true); pacing.stopLink(); publish(\.status, .blocked(state)) }
        return verdict
    }
    private func applyPolling() {
        guard started else { return }
        let observed = angleObserved || preferences.settings.showAngle
        pacing.setPolling(interval: suspended ? nil : LidPollingPolicy.interval(enabled: enabled, previewing: preview.isPreviewing, angleObserved: observed))
    }

    // MARK: System state

    /// System or screen sleep suspends live rendering; an inactive login session does not, so the effect is
    /// ready the moment the user's session resumes on the built-in display.
    private func systemStateChanged(_ event: SystemStateSubscriber.Event) {
        switch event {
        case .sleep: sleep()
        case .wake: wake()
        case .displaysChanged: displaysChanged()
        case .accessibility(let transparency, let motion): accessibilityChanged(reduceTransparency: transparency, reduceMotion: motion)
        }
    }
    private func sleep() {
        suspended = true
        if preview.isPreviewing { stopPreview() }
        tearDown(); publish(\.status, enabled ? .sleeping : .off); applyPolling()
    }
    private func wake() { suspended = false; lid.reopen(); gate.reset(); applyPolling() }
    private func displaysChanged() { tearDown(); tick() }
    /// Releases everything on screen; the next ready tick rebuilds it.
    private func tearDown() { session.stop(); pacing.stopLink(); gate.reset() }
    private func accessibilityChanged(reduceTransparency next: Bool, reduceMotion motion: Bool) {
        if next != reduceTransparency { session.stop() }
        publish(\.reduceTransparency, next); publish(\.reduceMotion, motion)
        if motion { pausePreview() }
    }

    // MARK: Publishing

    private func readLid(now: TimeInterval) {
        lid.read(now: now)
        publish(\.lidAngle, lid.angle); publish(\.sensorAvailable, lid.available); publish(\.diagnostic, lid.diagnostic)
    }
    private func publishTelemetry() {
        publish(\.captureFrames, session.captureFrames); publish(\.gpuMilliseconds, (session.renderer?.lastGPUTime ?? 0) * 1000)
    }
    private func publishPreview() {
        publish(\.isPreviewing, preview.isPreviewing); publish(\.isPlaying, preview.isPlaying)
        publish(\.previewEffectID, preview.effectID); publish(\.previewClosure, preview.closure)
    }
}
