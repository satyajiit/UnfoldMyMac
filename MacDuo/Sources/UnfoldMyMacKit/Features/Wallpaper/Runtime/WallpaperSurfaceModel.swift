import CoreGraphics
import Observation
import UnfoldMyMacCore

/// What the desktop windows show, owned by the desktop coordinator and observed by the layer views. No window
/// holds the feature model, so closing the windows releases everything (W3).
@MainActor @Observable final class WallpaperSurfaceModel {
    private(set) var template: WallpaperTemplate?
    private(set) var snapshot = WallpaperSnapshot()
    private(set) var animated = false
    private(set) var stats: [CGDirectDisplayID: RenderStats] = [:]

    /// The slowest display, so a struggling second screen is not hidden behind a fast first one (W2).
    var worstStats: RenderStats { stats.values.min { $0.fps < $1.fps } ?? RenderStats() }

    func reset(template: WallpaperTemplate?) {
        self.template = template; snapshot = WallpaperSnapshot(); stats = [:]
    }
    func update(snapshot: WallpaperSnapshot) { if self.snapshot != snapshot { self.snapshot = snapshot } }
    func setAnimated(_ value: Bool) { if animated != value { animated = value } }
    func record(_ value: RenderStats, for display: CGDirectDisplayID) { stats[display] = value }
}
