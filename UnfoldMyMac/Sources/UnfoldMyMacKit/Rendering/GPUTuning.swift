import Foundation

/// Rendering limits shared by every Metal surface in the app.
enum GPUTuning {
    /// Command buffers allowed in flight per surface; matches the drawable pool depth.
    static let maximumFramesInFlight = 3
    /// Longest edge, in pixels, that a wallpaper surface or thumbnail renders at.
    static let maximumWallpaperDimension = 1920.0
}
