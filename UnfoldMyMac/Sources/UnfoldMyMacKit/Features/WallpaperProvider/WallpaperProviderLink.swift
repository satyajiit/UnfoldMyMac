import AppKit
import Observation
import UnfoldMyMacCore

/// The app's end of the wallpaper provider bridge.
///
/// The extension renders inside a sandbox and cannot reach `~/.claude`, Codex history, the lid angle or the
/// microphone. This is the only thing that can: the app samples all of it anyway for its own windows, and
/// this writes that same snapshot into the extension's container on a cadence comfortably inside
/// `WallpaperDataSample.freshness`. It reads the extension's heartbeat back, which is how the app knows
/// whether the system is showing the provider or whether it must put up its own desktop windows instead.
@MainActor @Observable final class WallpaperProviderLink {
    /// `systemSlots` answers whether the user has chosen this provider for the lock screen, which the
    /// heartbeat cannot say on its own. Injected so a test exercises the link without reading — or being
    /// steered by — whatever this Mac's own wallpaper happens to be set to.
    init(bridge: WallpaperProviderBridge = .shared, stallGrace: TimeInterval = WallpaperProviderLink.defaultStallGrace,
         systemSlots: @escaping @MainActor () -> Bool? = { WallpaperSlotIndex.coversLockScreen() }) {
        self.bridge = bridge; self.stallGrace = stallGrace; self.systemSlots = systemSlots
    }
    /// A link on its own temporary directory, so a caller that must not see — or disturb — whatever the
    /// installed extension has written on this Mac can exercise the whole exchange in isolation.
    static func isolated() -> WallpaperProviderLink {
        WallpaperProviderLink(bridge: .init(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperProviderLink/\(UUID().uuidString)", isDirectory: true)),
            systemSlots: { nil })
    }

    private(set) var status = Status.unknown {
        didSet { if status != oldValue { onStatusChanged?(status) } }
    }
    /// Fires when the provider appears or disappears, so the app can hand the screen over or take it back.
    @ObservationIgnored var onStatusChanged: ((Status) -> Void)?
    /// How old a heartbeat may be before the provider counts as gone. Two missed writes plus slack: the
    /// extension stamps one on every acquire, invalidate and data refresh, and the app drives that refresh
    /// on the cadence below — whether it has data to send or only a probe.
    static let heartbeatLifetime: TimeInterval = 30
    /// How long to wait for a first heartbeat before concluding the provider is not showing. The app posts
    /// a Darwin notification on its first write and a running extension answers within milliseconds, so
    /// this only has to cover process scheduling — but until it elapses the app leaves the wallpaper alone.
    static let resolutionGrace: TimeInterval = 6
    /// Well inside the 15-second sample freshness window, so a running app never lets the scene fall back
    /// to its idle pose, and a quit app lets it go within one window rather than showing stale numbers.
    static let writeInterval: TimeInterval = 4

    private let bridge: WallpaperProviderBridge
    private let stallGrace: TimeInterval
    @ObservationIgnored private let systemSlots: @MainActor () -> Bool?
    private var source: (any WallpaperSnapshotSource)?
    /// The app's own scene choice, and when the user actually changed it.
    ///
    /// The date is nil until the user picks a different scene *in the app during this session*. Simply
    /// having a persisted preference is not a decision the user just made, and treating it as one would
    /// let a launch quietly overrule the wallpaper they chose in System Settings a moment earlier.
    private var selection: (id: String, changedAt: Date?)?
    private var enabled = false
    private var timer: Timer?
    private var startedAt: Date?
    /// When the provider first reported surfaces that were asking for motion and delivering none. A
    /// freshly acquired surface reports zero presented frames until its first second of statistics lands,
    /// so the condition has to hold for a while before it means anything.
    private var stalledSince: Date?
    /// Whether a heartbeat written while this link was watching has ever been read. Until it has, an old
    /// stamp on disk is someone else's leftover rather than this provider's answer.
    private var heard = false
    private var lastPayload: WallpaperProviderBridge.Payload?

    /// Points the bridge at the app's current selection. `templateID` is the scene the app's own picker
    /// has applied, which takes over a live surface immediately; with the app closed the extension falls
    /// back to the choice macOS persisted.
    ///
    /// Reading never stops while the app is up, even with the wallpaper feature off. Whether macOS is
    /// showing our provider decides whether the app may touch the system wallpaper at all, and that stays
    /// true — and has to stay known — when the app is drawing nothing itself.
    func update(enabled: Bool, templateID: String?, source: (any WallpaperSnapshotSource)?) {
        self.enabled = enabled
        self.source = source
        switch (selection, templateID) {
        case (_, nil): selection = nil
        case (nil, let id?): selection = (id, nil)
        case (let current?, let id?) where current.id != id: selection = (id, .now)
        default: break
        }
        if startedAt == nil { startedAt = .now }
        write()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.writeInterval, repeats: true) { _ in
            MainActor.assumeIsolated { WallpaperProviderLink.tick(self) }
        }
    }
    /// Shutdown only. Turning the wallpaper feature off does not stop the link; see `update`.
    func stop() {
        timer?.invalidate(); timer = nil
        lastPayload = nil
        startedAt = nil
        stalledSince = nil
        heard = false
        selection = nil
        status = .unknown
    }
    isolated deinit { timer?.invalidate() }

    private static func tick(_ link: WallpaperProviderLink) { link.write() }

    /// Writes the current snapshot and re-reads the heartbeat. Writing is cheap and unconditional while
    /// enabled: the extension may start at any moment and must find data already there.
    private func write() {
        readHeartbeat()
        guard enabled, let source else {
            // Nothing to send — but the extension stamps its heartbeat only when the app speaks to it, so
            // staying quiet would read back as a provider that had stopped, and a stopped provider is
            // exactly the reason the app has to send nothing. That silence latches. The probe asks the
            // question without overwriting the snapshot a live surface is already posed from.
            WallpaperProviderBridge.post()
            return
        }
        var payload = WallpaperProviderBridge.Payload()
        payload.sources = source.snapshot.sources
        payload.errors = source.snapshot.errors
        payload.inputs = source.liveInputs
        payload.templateID = selection?.id
        payload.selectedAt = selection?.changedAt
        // An unchanged payload still has to be rewritten: the freshness window is what makes a sample
        // count, and a sample that stops being rewritten is exactly how the scene learns the app is gone.
        lastPayload = payload
        do { try bridge.write(payload) }
        catch { WallpaperProviderLog.fault("bridge write failed: \(error.localizedDescription)") }
    }
    private func readHeartbeat() {
        let beat = bridge.readHeartbeat()
        guard let beat, Date.now.timeIntervalSince(beat.stampedAt) < Self.heartbeatLifetime else {
            // A stale heartbeat is only an answer once this link has heard a live one, or the stamp is
            // newer than the link itself. The file survives the app, and the extension writes to it only
            // when the app asks — so at launch an hours-old stamp says nothing except that nobody has
            // asked lately. Reading it as "the provider stopped" is what makes the app stop asking, and
            // the silence then keeps itself alive. Until either test passes, the grace window decides.
            let started = startedAt ?? .now
            let answered = heard || (beat?.stampedAt ?? .distantPast) > started
            status = answered || Date.now.timeIntervalSince(started) >= Self.resolutionGrace ? .idle : .unknown
            return
        }
        heard = true
        guard beat.failure == nil else { stalledSince = nil; status = .failed(beat.failure ?? ""); return }
        guard beat.surfaces > 0 else { stalledSince = nil; status = .idle; return }
        // Two sources, because neither answers alone. A live lock-screen surface is proof, but one exists
        // only while the lock screen is on screen — between unlocking and the next lock there is nothing
        // to report, and reading that silence as "not chosen for the lock screen" is the same shape of
        // wrong answer this whole change is about. The system's own store says what the user chose.
        let onLockScreen = beat.coversLockScreen || (systemSlots() ?? false)
        status = isStalled(beat) ? .stalled(templateID: beat.templateID)
            : .live(templateID: beat.templateID, onLockScreen: onLockScreen)
    }

    /// Whether a provider that holds surfaces is on screen and frozen.
    ///
    /// `framesPerSecond` is the rate the display link was asked for and `presentedFPS` the rate frames
    /// actually reached the screen, so the two disagreeing is the whole signal. A rate of 1 or 0 is a
    /// still scene by design — Reduce Motion, or a sleeping display — and never counts. An extension too
    /// old to report either sends zeroes, which reads as "not asking for motion" and stays quiet.
    private func isStalled(_ beat: WallpaperProviderBridge.Heartbeat) -> Bool {
        guard beat.framesPerSecond > 1, beat.presentedFPS <= 0 else { stalledSince = nil; return false }
        let since = stalledSince ?? .now
        stalledSince = since
        return Date.now.timeIntervalSince(since) >= stallGrace
    }
    /// Long enough for a newly acquired surface to produce its first second of statistics and for the app
    /// to have re-read the heartbeat at least twice after that.
    static let defaultStallGrace: TimeInterval = 12

    /// Where in System Settings a wallpaper choice is made. Selecting a provider is the user's decision
    /// and macOS offers no way for an app to make it — the honest move is to take them to the control
    /// rather than to write the system's wallpaper state behind its back.
    ///
    /// Two panes, because macOS keeps two selections per display: `Desktop` and `Idle`. The desktop
    /// wallpaper is the Wallpaper pane; the lock screen and the screen saver are the same `Idle` slot and
    /// are chosen in the Screen Saver pane. Picking a scene in the first does not put it in the second,
    /// which is why a wallpaper can be ours while the lock screen still shows Apple's exported still.
    enum SettingsPane: String {
        case wallpaper = "com.apple.Wallpaper-Settings.extension"
        case screenSaver = "com.apple.ScreenSaver-Settings.extension"
    }
    static func openSystemSettings(_ pane: SettingsPane = .wallpaper) {
        guard let url = URL(string: "x-apple.systempreferences:\(pane.rawValue)") else { return }
        // The user is being sent to change the very thing the cached reading describes.
        WallpaperSlotIndex.invalidate()
        NSWorkspace.shared.open(url)
    }
    /// True when this build actually carries the provider, so the UI can stay quiet in a build without it.
    static var isInstalled: Bool {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return false }
        return FileManager.default.fileExists(atPath: plugins.appendingPathComponent("UnfoldMyMacWallpaperExtension.appex").path)
    }
}
