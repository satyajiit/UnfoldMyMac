import Metal
import MetalKit

/// One Metal device, queue and set of caches per process. Every pipeline is built against a context
/// instead of creating its own device, so shader units compile once and pipeline states are shared.
@MainActor final class GPUContext {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let libraries: ShaderLibraryCache
    let pipelines = RenderPipelineCache()
    let textures: MTKTextureLoader

    init(device: MTLDevice? = MTLCreateSystemDefaultDevice(), libraryPolicy: ShaderLibraryCache.Policy = .preferPrecompiled) throws {
        guard let device, let queue = device.makeCommandQueue() else { throw GPUError.metalUnavailable }
        self.device = device; self.queue = queue
        libraries = ShaderLibraryCache(device: device, policy: libraryPolicy)
        textures = MTKTextureLoader(device: device)
    }
    /// A render pipeline state for one shader unit, cached by every input that affects it.
    func pipeline(_ module: ShaderModule, vertex: String, fragment: String, color: MTLPixelFormat,
                  depth: MTLPixelFormat = .invalid, blend: PipelineBlend = .opaque) throws -> MTLRenderPipelineState {
        let library = try libraries.library(for: module)
        return try pipelines.pipeline(library: library, unit: try libraries.unitKey(for: module), vertex: vertex, fragment: fragment,
                                      color: color, depth: depth, blend: blend)
    }
}
