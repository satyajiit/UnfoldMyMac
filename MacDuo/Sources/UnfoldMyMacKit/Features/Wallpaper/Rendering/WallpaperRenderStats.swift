import Foundation
import Synchronization

struct WallpaperRenderStats: Equatable, Sendable {
    var fps = 0.0
    var gpuMilliseconds = 0.0
    var width = 0
    var height = 0
    var p95FrameMilliseconds = 0.0
}
