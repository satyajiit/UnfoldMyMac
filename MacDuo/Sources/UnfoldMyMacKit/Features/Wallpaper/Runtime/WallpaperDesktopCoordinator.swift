import AppKit
import Observation
import UnfoldMyMacCore

/// Puts the active scene on every display and keeps it fed: one window controller per screen, one surface
/// model they all observe, and one observation of the desktop data hub.
@MainActor final class WallpaperDesktopCoordinator {
    let surface = WallpaperSurfaceModel()
    private(set) var controllers: [WallpaperDesktopWindowController] = []
    private let surfaces: DesktopSurfaceRegistry
    private let displays: any DisplayProviding
    private var pipeline: WallpaperPipeline?
    private var framesPerSecond = 0
    private var observation: Task<Void, Never>?

    init(surfaces: DesktopSurfaceRegistry, displays: any DisplayProviding) { self.surfaces = surfaces; self.displays = displays }
    var windows: [NSWindow] { controllers.compactMap(\.window) }
    var isShowing: Bool { !controllers.isEmpty }

    /// Rebuilds the windows for `pipeline` and follows `source` until `stop()`.
    func show(pipeline: WallpaperPipeline, source: any WallpaperSnapshotSource, framesPerSecond: Int, styleSheet: WallpaperStyle = .standard) {
        close()
        self.pipeline = pipeline; self.framesPerSecond = framesPerSecond
        surface.reset(template: pipeline.template, styleSheet: styleSheet); surface.setAnimated(framesPerSecond > 1)
        for screen in NSScreen.screens {
            controllers.append(WallpaperDesktopWindowController(screen: screen, displayID: displays.displayID(of: screen) ?? 0, pipeline: pipeline, surface: surface))
        }
        surfaces.update(Set(windows.compactMap { CGWindowID(exactly: $0.windowNumber) }))
        observation?.cancel()
        observation = Task { [weak self] in
            for await snapshot in Observations({ source.snapshot }) { self?.apply(snapshot: snapshot) }
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

    private func apply(snapshot: WallpaperSnapshot) { surface.update(snapshot: snapshot); push() }
    private func push() {
        guard let pipeline else { return }
        let pose = WallpaperPose(template: pipeline.template, snapshot: surface.snapshot)
        for controller in controllers { controller.apply(pose, framesPerSecond: framesPerSecond) }
    }
    private func close() {
        for controller in controllers { controller.close() }
        controllers.removeAll()
    }
}
