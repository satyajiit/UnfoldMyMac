import Metal

/// How a pipeline's drawable is configured; the renderer owns the layer, the pipeline declares its needs.
struct SurfaceConfiguration {
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
    var isOpaque = false
    var clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    var loadAction: MTLLoadAction = .clear
    /// Longest drawable edge in pixels, or nil to render at native resolution.
    var maximumDimension: Double? = nil
}

/// What every GPU pipeline implements. Encoding must be complete for one frame (clear included) and
/// return false only when nothing could be encoded; the renderer then presents a cleared frame.
@MainActor protocol MetalPipeline: AnyObject {
    associatedtype Frame: Equatable & Sendable
    var gpu: GPUContext { get }
    var surface: SurfaceConfiguration { get }
    /// False while an input the pipeline needs (a captured desktop frame) has not arrived.
    var isReady: Bool { get }
    /// Changes whenever the pipeline's own inputs changed, so an identical `Frame` still redraws.
    var contentGeneration: Int { get }
    /// The drawable size changed; per-size resources are rebuilt lazily.
    func prepare(size: CGSize)
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame: Frame) -> Bool
    func didStop()
}

extension MetalPipeline {
    var isReady: Bool { true }
    var contentGeneration: Int { 0 }
    func prepare(size: CGSize) {}
    func didStop() {}
}
