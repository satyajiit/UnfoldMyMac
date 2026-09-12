import AppKit
import Observation
import QuartzCore
import UniformTypeIdentifiers
import UnfoldMyMacCore

@MainActor @Observable public final class UnfoldMyMacModel: NSObject {
    private(set) var settings: UnfoldMyMacSettings
    var route: AppRoute? = .effects {
        didSet {
            if route != .effects {
                effectsPath = []
                if isPreviewing { stopPreview() }
            }
        }
    }
    var effectsPath: [EffectsDestination] = [] {
        didSet { if !effectsPath.isEmpty && isPreviewing { stopPreview() } }
    }
    private(set) var enabled = false
    private(set) var status = "Off"
    private(set) var lidAngle: Double?
    private(set) var sensorAvailable = false
    private(set) var diagnostic = "Checking lid sensor…"
    private(set) var errorMessage: String?
    private(set) var needsPermission = false
    private(set) var isPreviewing = false
    private(set) var previewEffectID: EffectID?
    private(set) var isPlaying = false
    private(set) var reduceTransparency = false
    private(set) var reduceMotion = false
    private(set) var displayName = "Built-in display unavailable"
    private(set) var captureFrames = 0
    private(set) var gpuMilliseconds = 0.0
    private(set) var previewClosure: Double = 0
    var onPreviewChanged: (() -> Void)?
    var onAppearanceChanged: (() -> Void)?
    var onStatusChanged: (() -> Void)?
    let registry: EffectRegistry
    let artworkLibrary: ArtworkLibrary?
    var libraryCategory: EffectCategory?
    var libraryQuery = ""
    var libraryTag: String?
    private(set) var isImporting = false
    var libraryMessage: String?
    @ObservationIgnored private var animationSeconds = 0.0
    @ObservationIgnored private let store: any SettingsStoring
    @ObservationIgnored private let makeSensor: () -> any LidReading
    @ObservationIgnored private var sensor: any LidReading
    @ObservationIgnored private let displays: any DisplayProviding
    @ObservationIgnored private let session: EffectSession
    @ObservationIgnored private let clock: () -> TimeInterval
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var safety = DisplaySafetyGate()
    @ObservationIgnored private var lastReading = -Double.infinity
    @ObservationIgnored private var lastReconnect = -Double.infinity
    @ObservationIgnored private var reconnectDelay = EffectTuning.sensorReconnectDelay
    @ObservationIgnored private var lastUIUpdate = -Double.infinity
    @ObservationIgnored private var playSeconds = 0.0
    @ObservationIgnored private var previousEnabled = false
    @ObservationIgnored private var suspended = false

    init(store: any SettingsStoring, registry: EffectRegistry, sensorFactory: @escaping () -> any LidReading,
         displays: any DisplayProviding, session: EffectSession, artworkLibrary: ArtworkLibrary? = nil, clock: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.artworkLibrary = artworkLibrary
        self.libraryMessage = artworkLibrary?.loadError ?? registry.catalogError
        self.store = store; self.registry = registry; self.makeSensor = sensorFactory; self.clock = clock
        sensor = sensorFactory(); self.displays = displays; self.session = session
        var loaded = store.load()
        loaded.sanitize()
        loaded.effect = registry.entry(for: loaded.effect).descriptor.id
        // Parameters for effects that no longer exist are dropped, unless the artwork index failed to load
        // and their owners may come back once it is repaired.
        if artworkLibrary?.loadError == nil, loaded.reconcile(effects: registry.descriptors.map(\.id)) { store.save(loaded) }
        settings = loaded
        super.init()
        session.onError = { [weak self] error in self?.failed(error) }
    }
    var selectedEffect: EffectDescriptor { registry.entry(for: settings.effect).descriptor }
    /// Trying an effect never overwrites the user's chosen design or its parameters.
    var activeEffect: EffectDescriptor { registry.entry(for: previewEffectID ?? settings.effect).descriptor }
    var angleLabel: String { lidAngle.map { "\(Int($0.rounded()))°" } ?? "—" }
    var parameters: EffectParameters { settings.parameters(for: settings.effect) }
    var needsCapture: Bool { activeEffect.requiresCapture && !reduceTransparency }

    func start() {
        accessibilityChanged()
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(wake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let polling = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(polling, forMode: .common)
        timer = polling
        tick()
    }
    func shutdown() {
        timer?.invalidate(); timer = nil
        stopLink(); session.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    func setEnabled(_ value: Bool) {
        if isPreviewing {
            // The preview keeps the effect running; the choice applies once the preview ends.
            previousEnabled = value
            guard !value else { onStatusChanged?(); return }
            stopPreview()
        }
        enabled = value; errorMessage = nil; needsPermission = false
        if !value { session.stop(); stopLink(); status = "Off" }
        else { safety.reset(); tick() }
        onStatusChanged?()
    }
    func selectEffect(_ id: EffectID) {
        if isPreviewing { stopPreview() }
        guard id != settings.effect else { return }
        session.stop(); animationSeconds = 0; settings.effect = registry.entry(for: id).descriptor.id
        persist(); errorMessage = nil; needsPermission = false; tick()
        onStatusChanged?()
    }
    func setStrength(_ strength: Double) {
        var next = parameters
        next.strength = strength.isFinite ? min(1, max(0, strength)) : 1
        settings.parameters[settings.effect.rawValue] = next
        persist()
    }
    func setReveal(_ reveal: ArtRevealMotion) {
        var next = parameters; next.reveal = reveal
        settings.parameters[settings.effect.rawValue] = next; persist()
    }
    func chooseArtwork() {
        guard !isImporting, artworkLibrary != nil else { return }
        let panel = NSOpenPanel()
        panel.title = "Add an image to \(AppIdentity.name)"
        panel.prompt = "Add Image"
        panel.message = "Your image is copied into \(AppIdentity.name). PNG, JPEG, HEIC, and other supported images, up to 50 MB."
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in await self?.importArtwork(at: url) }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func importArtwork(at url: URL) async {
        guard !isImporting, let artworkLibrary else { return }
        isImporting = true; libraryMessage = nil
        defer { isImporting = false }
        do {
            let artwork = try await artworkLibrary.importImage(at: url)
            try registry.register(.artwork(artwork))
            libraryCategory = .image; libraryTag = nil; libraryQuery = ""
            selectEffect(artwork.id)
        } catch { libraryMessage = error.localizedDescription }
    }
    func updateArtworkCredits(title: String, author: String) {
        do {
            guard let artwork = try artworkLibrary?.update(id: settings.effect, title: title, author: author) else { return }
            registry.removeImported(artwork.id); try registry.register(.artwork(artwork))
            libraryMessage = nil; onStatusChanged?()
        } catch { libraryMessage = error.localizedDescription }
    }
    @discardableResult func removeArtwork(_ id: EffectID) -> Bool {
        guard registry.entry(for: id).descriptor.isImported, let artworkLibrary else { return false }
        do {
            try artworkLibrary.remove(id)
            if previewEffectID == id { stopPreview() }
            if settings.effect == id { selectEffect(.reverie) }
            registry.removeImported(id); settings.parameters[id.rawValue] = nil; persist()
            libraryMessage = nil; return true
        } catch { libraryMessage = error.localizedDescription; return false }
    }
    func setActivation(_ angle: Double) {
        guard angle.isFinite else { return }
        settings.activation = angle.clamped(to: EffectTuning.activationRange).rounded()
        persist(); tick()
    }
    func setCompletionFraction(_ fraction: Double) { settings.completionFraction = fraction.clamped(to: EffectTuning.completionRange); persist() }
    var completionAngle: Double { EffectMath.completionAngle(activation: settings.activation, completionFraction: settings.completionFraction) }
    var effectProgress: Double { EffectMath.calibratedClosure(previewClosure, completionFraction: settings.completionFraction) }
    func anchorHere() { if sensorAvailable, let lidAngle { setActivation(lidAngle) } }
    func setAppearance(_ appearance: AppearancePreference) { settings.appearance = appearance; persist(); onAppearanceChanged?() }
    func setShowAngle(_ value: Bool) { settings.showAngle = value; persist(); onStatusChanged?() }
    func persist() { store.save(settings) }

    func togglePreview(for id: EffectID) {
        if isPreviewing && previewEffectID == id { stopPreview(); return }
        beginPreview(effect: id)
        if !reduceMotion { playPreview() }
    }
    func showEffectSettings() {
        route = .effects
        effectsPath = [.settings]
    }
    func beginPreview(effect id: EffectID? = nil) {
        let next = registry.entry(for: id ?? settings.effect).descriptor.id
        if isPreviewing {
            guard previewEffectID != next else { return }
            session.stop(); stopLink()
        } else { previousEnabled = enabled }
        route = .effects
        effectsPath = []
        previewEffectID = next; isPreviewing = true; isPlaying = false
        errorMessage = nil; needsPermission = false
        enabled = true; previewClosure = 0; animationSeconds = 0
        safety.reset(); tick(); onPreviewChanged?()
    }
    func playPreview() {
        guard !reduceMotion else { return }
        if !isPreviewing { beginPreview() }
        guard isPreviewing else { return }
        playSeconds = 1.2 + acos(1 - 2 * min(1, max(0, previewClosure))) / .pi * 3.1
        isPlaying = true
    }
    func pausePreview() { isPlaying = false }
    func scrubPreview(_ value: Double) { isPlaying = false; previewClosure = min(1, max(0, value)) }
    func stopPreview() {
        guard isPreviewing else { return }
        isPreviewing = false; isPlaying = false; enabled = previousEnabled
        previewEffectID = nil; previewClosure = 0; animationSeconds = 0
        session.stop(); stopLink(); safety.reset()
        status = enabled ? "Ready" : "Off"
        onPreviewChanged?(); onStatusChanged?(); tick()
    }
    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
    }
    private func failed(_ error: Error) {
        let requestedCapture = needsCapture
        // Only a failure of the chosen effect turns effects off. A failed card preview ends the preview
        // and lets the chosen effect resume with the user's enabled state intact.
        let chosenFailed = !isPreviewing || previewEffectID == settings.effect
        if isPreviewing {
            if chosenFailed { previousEnabled = false }
            stopPreview()
        }
        if chosenFailed { enabled = false; session.stop(); stopLink() }
        needsPermission = requestedCapture && !CGPreflightScreenCaptureAccess()
        errorMessage = needsPermission ? "Allow \(AppIdentity.name) in System Settings → Privacy & Security → Screen Recording, then enable Frost again." : error.localizedDescription
        if chosenFailed { status = needsPermission ? "Screen Recording needed" : "Effect unavailable" }
        onStatusChanged?()
    }
    private func readLid(now: TimeInterval) {
        if let angle = sensor.read() {
            lidAngle = angle; lastReading = now; reconnectDelay = EffectTuning.sensorReconnectDelay
        } else if now - lastReconnect >= reconnectDelay {
            // Rebuilding the HID manager is expensive; back off instead of retrying every two seconds forever.
            lastReconnect = now
            reconnectDelay = min(EffectTuning.sensorReconnectCeiling, reconnectDelay * 2)
            sensor = makeSensor()
        }
        sensorAvailable = now - lastReading <= 1
        if !sensorAvailable { lidAngle = nil }
        diagnostic = sensorAvailable ? "Lid sensor connected · read-only" : sensor.diagnostic
    }
    func tick() {
        let now = clock()
        // Live rendering reads immediately before each frame. Poll only while idle or previewing.
        if displayLink == nil || isPreviewing { readLid(now: now) }
        let screen = displays.builtInScreen()
        displayName = screen?.localizedName ?? "Built-in display unavailable"
        if now - lastUIUpdate >= 0.25 {
            lastUIUpdate = now
            captureFrames = session.captureFrames
            gpuMilliseconds = (session.renderer?.lastGPUTime ?? 0) * 1000
            onStatusChanged?()
        }
        guard enabled, !suspended else { return }
        // Preview overrides missing angle input, never physical clamshell/display safety.
        let closed = displays.lidClosed(now: now) == true || (sensorAvailable && (lidAngle ?? 180) <= EffectMath.closedLid)
        guard safety.update(lidClosed: closed, builtInAvailable: screen != nil, sensorAvailable: sensorAvailable || isPreviewing, now: now), let screen else {
            session.stop(); stopLink(); status = safety.state.rawValue
            return
        }
        session.start(effect: activeEffect.id, screen: screen, reduceTransparency: reduceTransparency)
        guard enabled else { return }
        startLink(screen: screen)
        if session.renderer?.ready != true { status = "Preparing \(activeEffect.title)…" }
        else if isPreviewing { status = "Previewing \(activeEffect.title)" }
        else if (lidAngle ?? 180) > settings.activation { status = "Ready · close to \(Int(settings.activation))°" }
        else { status = "\(selectedEffect.title) active" }

    }
    private func startLink(screen: NSScreen) {
        guard displayLink == nil else { return }
        let link = screen.displayLink(target: self, selector: #selector(render(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    private func stopLink() { displayLink?.invalidate(); displayLink = nil }
    @objc private func render(_ link: CADisplayLink) {
        renderFrame(deltaTime: link.targetTimestamp - link.timestamp)
    }
    func renderFrame(deltaTime: TimeInterval) {
        guard enabled, !suspended, safety.state == .ready, session.renderer != nil else { return }
        let dt = min(0.05, max(1.0 / 240, deltaTime))
        if isPlaying {
            playSeconds += dt; previewClosure = EffectMath.playClosure(seconds: playSeconds)
        }
        let progress: Double
        if isPreviewing {
            progress = EffectMath.calibratedClosure(previewClosure, completionFraction: settings.completionFraction)
        } else {
            readLid(now: clock())
            guard sensorAvailable, let lidAngle, lidAngle > EffectMath.closedLid else {
                tick() // Apply the existing sensor-loss and physical-lid safety gates immediately.
                return
            }
            progress = EffectMath.liveProgress(lid: lidAngle, activation: settings.activation, completionFraction: settings.completionFraction)
        }
        // No temporal filter: a fresh angle or a scrub position controls this frame directly.
        if progress > 0, !reduceMotion, (!isPreviewing || isPlaying) { animationSeconds += dt }
        session.update(.init(closure: progress, parameters: settings.parameters(for: activeEffect.id), reduceTransparency: reduceTransparency,
            time: session.renderer?.animatesWithTime == true ? animationSeconds : 0, reduceMotion: reduceMotion))
    }
    @objc private func sleep() {
        suspended = true
        if isPreviewing { stopPreview() }
        session.stop(); stopLink(); safety.reset(); status = enabled ? "Paused · sleeping" : "Off"
    }
    @objc private func wake() {
        suspended = false; lastReading = -.infinity; reconnectDelay = EffectTuning.sensorReconnectDelay
        sensor = makeSensor(); safety.reset()
    }
    @objc private func displaysChanged() { session.stop(); stopLink(); safety.reset(); tick() }
    @objc private func accessibilityChanged() {
        let workspace = NSWorkspace.shared
        let next = workspace.accessibilityDisplayShouldReduceTransparency
        if next != reduceTransparency { session.stop() }
        reduceTransparency = next
        reduceMotion = workspace.accessibilityDisplayShouldReduceMotion
        if reduceMotion { pausePreview() }
    }
}
