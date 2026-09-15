import AppKit
import Observation
import UnfoldMyMacCore

/// Puts the active scene on the primary display and keeps it fed: one window controller, one surface
/// model it observes, and one observation of the desktop data hub.
///
/// The primary display only, deliberately. The scene is composed for one screen — its readouts, marks and
/// safe areas are placed against a single aspect ratio — and painting the same composition across a
/// built-in panel and an ultrawide gives the second one a layout nobody designed. Until the scene can be
/// laid out per display, the other screens keep the wallpaper their owner chose.
@MainActor final class WallpaperDesktopCoordinator {
    let surface = WallpaperSurfaceModel()
    private(set) var controllers: [WallpaperDesktopWindowController] = []
    private let surfaces: DesktopSurfaceRegistry
    private let displays: any DisplayProviding
    private var pipeline: WallpaperPipeline?
    private let inputs: WallpaperInputService?
    private var framesPerSecond = 0
    private var liveInputs = WallpaperLiveInputs()
    private var observation: Task<Void, Never>?

    init(surfaces: DesktopSurfaceRegistry, displays: any DisplayProviding, inputs: WallpaperInputService? = nil) {
        self.surfaces = surfaces; self.displays = displays; self.inputs = inputs
    }
    var windows: [NSWindow] { controllers.compactMap(\.window) }
    var isShowing: Bool { !controllers.isEmpty }

    /// Rebuilds the windows for `pipeline` and follows `source` until `stop()`.
    func show(pipeline: WallpaperPipeline, source: any WallpaperSnapshotSource, framesPerSecond: Int, styleSheet: WallpaperStyle = .standard) {
        close()
        self.pipeline = pipeline; self.framesPerSecond = framesPerSecond
        surface.reset(template: pipeline.template, styleSheet: styleSheet); surface.setAnimated(framesPerSecond > 1)
        if let screen = primaryScreen {
            controllers.append(WallpaperDesktopWindowController(screen: screen, displayID: displays.displayID(of: screen) ?? 0, pipeline: pipeline, surface: surface, inputs: inputs))
        }
        surfaces.update(Set(windows.compactMap { CGWindowID(exactly: $0.windowNumber) }))
        observation?.cancel()
        observation = Task { [weak self] in
            for await (snapshot, inputs) in Observations({ (source.snapshot, source.liveInputs) }) {
                self?.liveInputs = inputs; self?.apply(snapshot: snapshot)
            }
        }
    }
    func setFramesPerSecond(_ fps: Int) {
        guard fps != framesPerSecond else { return }
        framesPerSecond = fps; surface.setAnimated(fps > 1); push()
    }
    func stop() {
        observation?.cancel(); observation = nil
        close(); surfaces.update([])
        surface.reset(template: nil); pipeline = nil
    }
    isolated deinit { observation?.cancel(); close() }

    /// The display carrying the menu bar, falling back to the first screen AppKit reports. The fallback
    /// matters on a Mac whose menu-bar display has just been disconnected: `CGMainDisplayID` can name a
    /// display `NSScreen` no longer lists, and returning nothing there would leave the desktop blank
    /// rather than move the scene to the screen that is still attached.
    private var primaryScreen: NSScreen? {
        let primary = CGMainDisplayID()
        return NSScreen.screens.first { displays.displayID(of: $0) == primary } ?? NSScreen.screens.first
    }
    /// The display the scene is drawn on, for the interface to name. Computed from the same screen the
    /// windows are built on, so the row can never name one display while another shows the wallpaper.
    var target: WallpaperBackdropScreen? { primaryScreen.map { WallpaperBackdropScreen($0) } }
    private func apply(snapshot: WallpaperSnapshot) { surface.update(snapshot: snapshot); push() }
    private func push() {
        guard let pipeline else { return }
        var pose = WallpaperPose(template: pipeline.template, snapshot: surface.snapshot)
        pose.liveInputs = liveInputs
        for controller in controllers { controller.apply(pose, framesPerSecond: framesPerSecond) }
    }
    private func close() {
        for controller in controllers { controller.close() }
        controllers.removeAll()
    }
}
