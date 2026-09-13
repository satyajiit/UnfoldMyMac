import Foundation
import Observation
import UnfoldMyMacCore

/// The updater the interface talks to: one owner of `state`, and the only writer of it.
///
/// A check nobody asked for can never raise anything. `UpdatePolicy` decides what a result means and
/// takes the trigger as an argument, so "quiet in the background, always answers a click" is a
/// property of the transition rather than a rule spread across call sites.
@MainActor @Observable final class UpdateModel {
    private(set) var state: UpdateState = .idle
    /// Whether the sheet should be on screen. Separate from `state` so Remind Me Later can dismiss the
    /// sheet while the sidebar badge stays.
    private(set) var promptPending = false
    private(set) var preferences = UpdatePreferences()

    let currentVersion: AppVersion
    @ObservationIgnored private let store: any PreferencesStore
    @ObservationIgnored private let feed: any ReleaseFeedReading
    @ObservationIgnored private let flow: UpdateInstallFlow
    @ObservationIgnored private let installer: any BundleInstalling
    @ObservationIgnored private let environment: any UpdateEnvironmentProbing
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var schedule = UpdatePolicy.schedule()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var windowVisible = false
    @ObservationIgnored private var awaitingWindow = false
    @ObservationIgnored private var rateLimitedUntil: Date?

    init(preferences store: any PreferencesStore, currentVersion: AppVersion,
         feed: any ReleaseFeedReading = ReleaseFeed(),
         flow: UpdateInstallFlow = UpdateInstallFlow(),
         installer: any BundleInstalling = RenameSwapInstaller(),
         environment: any UpdateEnvironmentProbing = BundleUpdateEnvironment(),
         now: @escaping @Sendable () -> Date = { .now }) {
        self.store = store; self.currentVersion = currentVersion; self.feed = feed
        self.flow = flow; self.installer = installer
        self.environment = environment; self.now = now
        preferences = store.load(UpdatePreferences.key)
    }

    // MARK: Lifecycle

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in await self?.run() }
    }

    func shutdown() { loop?.cancel(); loop = nil; work?.cancel(); work = nil }

    private func run() async {
        if let report = UpdateLaunchReport.read(currentVersion: currentVersion, at: flow.paths.handoff) { state = report }
        switch await environment.eligibility() {
        case .blocked(let block): state = .unsupported(block); return
        case .eligible: break
        }
        UpdateSweeper.sweep(currentVersion: currentVersion, installRoot: environment.bundleURL.deletingLastPathComponent(),
                            paths: flow.paths)
        // Let the window settle first: the check must never compete with launch, and presenting a
        // sheet in the same turn a window first appears is unreliable.
        guard await sleep(seconds: 8) else { return }
        while !Task.isCancelled {
            if preferences.automaticChecks, isDue { await check(.automatic) }
            guard await sleep(seconds: 900) else { return }
        }
    }

    /// Slices rather than one long sleep: a sleep deadline is not extended across system sleep, so a
    /// single six-hour wait fires late after a night with the lid closed.
    private func sleep(seconds: Double) async -> Bool {
        do { try await Task.sleep(for: .seconds(seconds)); return true } catch { return false }
    }

    private var isDue: Bool {
        if let until = rateLimitedUntil, now() < until { return false }
        return schedule.isDue(at: now())
    }

    // MARK: Commands

    func checkNow(_ trigger: UpdateTrigger = .manual) {
        guard !isUnsupported, work == nil else { return }
        work = Task { [weak self] in await self?.check(trigger); self?.work = nil }
    }

    private func check(_ trigger: UpdateTrigger) async {
        guard !isUnsupported else { return }
        state = .checking(trigger)
        apply(await outcome(), trigger: trigger)
    }

    private func outcome() async -> UpdateOutcome {
        do {
            var release = try await feed.latest()
            // Notes cost an API call, so they are fetched only when there is something to show.
            if release.version > currentVersion { release.notes = await feed.notes(for: release) }
            return .discovered(release)
        } catch let error as UpdateError {
            if case .rateLimited(let until) = error { rateLimitedUntil = until }
            return .failure(error)
        } catch {
            return .failure(UpdateNetworkError.mapped(error))
        }
    }

    private func apply(_ outcome: UpdateOutcome, trigger: UpdateTrigger) {
        let next = UpdatePolicy.next(after: outcome, trigger: trigger,
                                     skipped: preferences.skipped, current: currentVersion, now: now())
        if case .failure(let error) = outcome {
            schedule.failed(error.errorDescription ?? "", at: now())
        } else {
            schedule.succeeded(at: now())
            preferences.lastCheck = now()
            save()
        }
        state = next
        if case .available(let release) = next { raisePrompt(for: release, trigger: trigger) }
    }

    private func raisePrompt(for release: UpdateRelease, trigger: UpdateTrigger) {
        switch UpdatePromptPolicy.decide(trigger: trigger, windowVisible: windowVisible,
                                         lastSeen: preferences.lastSeen, release: release) {
        case .present: present(release)
        case .waitForWindow: awaitingWindow = true
        case .ignore: break
        }
    }

    private func present(_ release: UpdateRelease) {
        promptPending = true
        preferences.lastSeenVersion = release.version.description
        save()
    }

    func windowDidBecomeVisible() {
        windowVisible = true
        guard awaitingWindow, case .available(let release) = state else { return }
        awaitingWindow = false
        present(release)
    }
    func windowDidHide() { windowVisible = false }
    func showPrompt() { promptPending = true }
    func dismissPrompt() { promptPending = false }
    /// Later keeps the badge: the update is still there, the sheet simply is not.
    func remindLater() { promptPending = false }

    func skipThisVersion() {
        if let release = state.release { preferences.skippedVersion = release.version.description; save() }
        promptPending = false
        state = .idle
    }

    func setAutomaticChecks(_ value: Bool) { preferences.automaticChecks = value; save() }

    private func save() { store.save(preferences, for: UpdatePreferences.key) }
    private var isUnsupported: Bool { if case .unsupported = state { return true } else { return false } }

    // MARK: Installing

    func beginDownload() {
        guard case .available(let release) = state, work == nil else { return }
        work = Task { [weak self] in await self?.downloadAndStage(release); self?.work = nil }
    }

    func cancelDownload() {
        work?.cancel(); work = nil
        if let release = state.release { state = .available(release) }
    }

    private func downloadAndStage(_ release: UpdateRelease) async {
        let runner = UpdateInstallRunner(flow: flow, paths: flow.paths, environment: environment,
                                         currentVersion: currentVersion, now: now)
        let settled = await runner.run(release) { [weak self] intermediate in self?.state = intermediate }
        // A cancel already moved the state back; do not overwrite it with a stale result.
        guard work != nil || !Task.isCancelled else { return }
        state = settled
    }

    func relaunch() {
        guard case .readyToRelaunch(let release, let staged) = state else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await installer.handOff(staged: staged, target: environment.bundleURL, version: release.version)
                UpdateRelaunch.quit()
            } catch let error as UpdateError {
                state = .failed(UpdateFailure(error, phase: .stage))
            } catch {
                state = .failed(UpdateFailure(.appMovedDuringInstall, phase: .stage))
            }
        }
    }

}
