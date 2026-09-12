import UnfoldMyMacCore

/// Everything a scene shader needs for one frame.
struct WallpaperFrame: Equatable, Sendable {
    var time = 0.0
    var energy = 0.0
    var channels = SIMD4<Float>.zero
    var grid: WallpaperScalarGrid? = nil
    /// The pose covers and system stills are rendered at.
    static let cover = WallpaperFrame(time: 4, energy: 0.35)
}
