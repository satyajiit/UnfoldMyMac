import AppKit
import IOSurface
import QuartzCore
import UnfoldMyMacCore
import UnfoldMyMacWallpaperBridge

/// One hosted wallpaper surface: a scene rendering into a remote `CAContext` the WindowServer composites.
///
/// This is the extension's counterpart to `WallpaperSurfaceRenderer`. It drives the same `WallpaperPipeline`
/// through the same `MetalSurfaceRenderer` and `DisplayLinkFrameDriver`, so the desktop and the lock screen
/// run identical Metal with identical pacing. The differences are all lifecycle: there is no AppKit view,
/// geometry arrives from the host's creation request rather than from layout, and pause and resume follow
/// the presentation mode and activity state the host pushes.
///
/// Each surface owns its own `CAContext`. A context can be hosted in only one `CALayerHost` at a time, so
/// the desktop, the Settings preview and every additional display must not share one.
@MainActor final class WallpaperProviderSurface {
    let contextID: UInt32
    let templateID: String
    /// What this surface is for. Reported back in the heartbeat: the app cannot otherwise tell a
    /// desktop-only provider from one that is also on the lock screen.
    let role: WallpaperProviderRequest.Role
    /// A System Settings tile rather than a wallpaper. It renders the same scene and reaches no screen.
    let isPreview: Bool
    /// The rate the display link is configured to, and the rate frames are actually reaching the screen.
    /// Nothing else in the extension can distinguish a live scene from one frozen on its first frame.
    var framesPerSecond: Int { playback.framesPerSecond }
    private(set) var presentedFPS = 0.0
    private let context: CAContext
    private let rootLayer = CALayer()
    private let metalLayer = CAMetalLayer()
    private let pipeline: WallpaperPipeline
    private let layers: WallpaperProviderLayers?
    private let driver: DisplayLinkFrameDriver<WallpaperPipeline>
    private var smoother: WallpaperFrameSmoother
    private var playback = WallpaperPlayback()
    /// The most recent frame handed to the display link, reused for snapshots so exporting a still never
    /// perturbs the animation the user is watching.
    private var lastFrame: WallpaperFrame

    /// Builds the context, the layer tree and the renderer. Returns nil when the scene or the remote
    /// context is unavailable — the one failure the host must see as a failed acquire rather than as a
    /// black wallpaper.
    init?(templateID: String, size: CGSize, scale: CGFloat, displayID: UInt32?, isPreview: Bool,
          role: WallpaperProviderRequest.Role) {
        guard let pipeline = try? WallpaperProviderEnvironment.shared.makePipeline(templateID: templateID) else {
            WallpaperProviderLog.fault("no pipeline for \(templateID)")
            return nil
        }
        guard let context = WallpaperProviderRuntime.makeRemoteContext(displayID: displayID) else { return nil }
        self.context = context
        contextID = context.contextId
        self.templateID = templateID
        self.role = role
        self.isPreview = isPreview
        self.pipeline = pipeline

        var smoother = WallpaperFrameSmoother(template: pipeline.template)
        let first = smoother.advance(delta: 0, animating: false)
        self.smoother = smoother
        lastFrame = first
        playback.enabled = true
        playback.preview = isPreview
        playback.maximumFPS = pipeline.template.fpsCeiling ?? 60

        rootLayer.frame = CGRect(origin: .zero, size: size)
        rootLayer.contentsScale = scale
        rootLayer.isOpaque = true
        rootLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalLayer.frame = rootLayer.bounds

        let renderer = MetalSurfaceRenderer(pipeline: pipeline, layer: metalLayer)
        renderer.prepare(size: size, scale: scale)
        layers = WallpaperProviderLayers(template: pipeline.template, styleSheet: WallpaperProviderEnvironment.shared.style,
                                         size: size, scale: scale)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rootLayer.addSublayer(metalLayer)
        if let layers { rootLayer.addSublayer(layers.layer) }
        CATransaction.commit()

        // Draw one frame before the display link exists, for two reasons. A remote context hosted while
        // still empty shows black, and `CALayer.contents` does not composite across processes, so the
        // first thing on screen has to be a real Metal present. And once a `CAMetalDisplayLink` is
        // attached to a layer, `nextDrawable` raises `CAMetalLayerInvalidOperation` — which is the path
        // `render(_:)` takes — so this is the only moment it can happen.
        renderer.render(first)

        driver = DisplayLinkFrameDriver(renderer: renderer)
        driver.frameSource = { [unowned self] delta, animating in
            let frame = self.smoother.advance(delta: delta, animating: animating)
            lastFrame = frame
            return frame
        }
        // The only proof that this surface is moving. Without it the log reports the rate the link was
        // asked for, a paused link and a live one read identically, and a scene frozen on the frame drawn
        // at line 75 looks exactly like one running at 60 fps.
        driver.onStats = { [weak self] stats in self?.record(stats) }
        context.layer = rootLayer
        CATransaction.flush()

        applyPlayback()
        WallpaperProviderLog.note("surface up: \(templateID) ctx=\(contextID) \(Int(size.width))x\(Int(size.height))@\(scale)x role=\(role.rawValue) preview=\(isPreview)")
    }

    /// One second of presented frames, sampled by the display link. Logged no more than once every five
    /// seconds: this runs for the life of the wallpaper, and a per-second line would be the noisiest thing
    /// in the system log.
    private func record(_ stats: RenderStats) {
        presentedFPS = stats.fps
        guard Date.now.timeIntervalSince(loggedStatsAt) >= Self.statsLogInterval else { return }
        loggedStatsAt = .now
        WallpaperProviderLog.note("frames \(templateID) role=\(role.rawValue) ctx=\(contextID) "
            + "presented=\(String(format: "%.1f", stats.fps))fps configured=\(framesPerSecond) \(stats.width)x\(stats.height)")
    }
    private static let statsLogInterval: TimeInterval = 5
    private var loggedStatsAt = Date.distantPast

    func resize(to size: CGSize, scale: CGFloat) {
        guard rootLayer.bounds.size != size || rootLayer.contentsScale != scale else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rootLayer.frame = CGRect(origin: .zero, size: size)
        rootLayer.contentsScale = scale
        metalLayer.frame = rootLayer.bounds
        CATransaction.commit()
        driver.renderer.prepare(size: size, scale: scale)
        layers?.resize(to: size, scale: scale)
    }

    /// The scene's data-driven pose. Live values come from the app over the data bridge; with no snapshot
    /// yet the template's declared idle pose keeps the scene moving rather than flat.
    func apply(pose: WallpaperPose, snapshot: WallpaperSnapshot) {
        smoother.setTargets(energy: pose.energy, channels: pose.channels, grid: pose.grid)
        smoother.targetLiveInputs = pose.liveInputs
        layers?.update(snapshot: snapshot, animated: playback.animates)
    }

    /// Host-driven playback. `idle` is the screen saver and `locked` is the lock screen: both are surfaces
    /// the user is looking at, so neither pauses. Only a session that is not on screen does.
    func apply(presentationMode: String?, activityState: String?) {
        playback.sleeping = Self.isSuspended(activityState)
        playback.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        playback.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        playback.thermallyLimited = ProcessInfo.processInfo.thermalState == .serious
            || ProcessInfo.processInfo.thermalState == .critical
        applyPlayback()
        WallpaperProviderLog.note("playback \(templateID) mode=\(presentationMode ?? "-") activity=\(activityState ?? "-") fps=\(playback.framesPerSecond)")
    }

    /// Whether the host's activity state means nobody can see this surface.
    ///
    /// The vocabulary belongs to the framework. `active` and `suspended` are the only two observed on
    /// macOS 26.6, and `suspended` is what arrives when the display sleeps — the log shows it landing
    /// about five minutes after a lock, never at the lock itself.
    ///
    /// Only `suspend…` pauses. The earlier version also matched `inactive` and `sleep`, which were
    /// guesses: no release has ever sent either, and both are plausible names for a state that is still
    /// on screen. Guessing wrong in that direction freezes a wallpaper the user is looking at, which is
    /// far worse than the battery a wrong guess in the other direction costs. Anything unrecognised is
    /// treated as visible and logged once, so a rename shows up as a line rather than as a still image.
    static func isSuspended(_ activityState: String?) -> Bool {
        guard let state = activityState?.lowercased() else { return false }
        if state.hasPrefix("suspend") { return true }
        if state != "active" { noteUnknownActivityState(state) }
        return false
    }
    private nonisolated(unsafe) static var reportedActivityStates: Set<String> = []
    private static func noteUnknownActivityState(_ state: String) {
        guard reportedActivityStates.insert(state).inserted else { return }
        WallpaperProviderLog.note("activity state '\(state)' is not one this build knows; treating the surface as visible")
    }
    private func applyPlayback() { driver.configure(framesPerSecond: playback.framesPerSecond) }

    /// Renders the scene's current frame into an IOSurface for the host's snapshot, which is what
    /// `wallpaperexportd` mirrors to `/var/db/Wallpapers` for the login window.
    func snapshotSurface() -> IOSurfaceRef? {
        WallpaperProviderSnapshot.surface(pipeline: pipeline, frame: lastFrame,
                                          size: rootLayer.bounds.size, scale: rootLayer.contentsScale)
    }

    func invalidate() {
        driver.stop()
        presentedFPS = 0
        playback.enabled = false
        context.layer = nil
        WallpaperProviderLog.note("surface down: \(templateID) ctx=\(contextID)")
    }
}
