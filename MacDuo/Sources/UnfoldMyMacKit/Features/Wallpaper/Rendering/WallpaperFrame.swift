import UnfoldMyMacCore

/// Everything a scene shader needs for one frame.
struct WallpaperFrame: Equatable, Sendable {
    var time = 0.0
    var energy = 0.0
    var channels = SIMD4<Float>.zero
    var grid: WallpaperScalarGrid? = nil
    init(time: Double = 0, energy: Double = 0, channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) {
        self.time = time; self.energy = energy; self.channels = channels; self.grid = grid
    }
    /// A template's fixed pose: what its cover and system still are rendered at.
    init(pose: WallpaperPosePreset) { self.init(time: pose.time, energy: pose.energy, channels: pose.channelVector) }
}
