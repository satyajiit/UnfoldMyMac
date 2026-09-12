import Foundation

/// One second of presented-frame statistics for a surface.
struct RenderStats: Equatable, Sendable {
    var fps = 0.0
    var gpuMilliseconds = 0.0
    var width = 0
    var height = 0
    var p95FrameMilliseconds = 0.0
}
