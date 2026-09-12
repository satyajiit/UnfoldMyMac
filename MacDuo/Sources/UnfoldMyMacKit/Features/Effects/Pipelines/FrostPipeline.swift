import AppKit
import MetalKit
import UnfoldMyMacCore

private struct FrostUniforms {
    var motion: Float
    var finalFade: Float
    var strength: Float
    var pad: Float = 0
    var pixel: SIMD2<Float>
    var padding: SIMD2<Float> = .zero
}

@MainActor final class FrostPipeline {
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    init() throws {
        guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
            throw GPUError.metalUnavailable
        }
        self.gpu = gpu; self.queue = queue
        let library = try gpu.makeLibrary(source: BundleResources.shaderSource("Frost", family: .effects), options: nil)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "frostVertex")
        desc.fragmentFunction = library.makeFunction(name: "frostFragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipeline = try gpu.makeRenderPipelineState(descriptor: desc)
    }
    func makeMips(source: MTLTexture) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: source.width, height: source.height, mipmapped: true)
        desc.storageMode = .private
        desc.usage = [.shaderRead, .shaderWrite]
        return gpu.makeTexture(descriptor: desc)
    }
    /// Shared by onscreen and deterministic offscreen tests. All textures live through command completion.
    func encode(command: MTLCommandBuffer, source: MTLTexture, mips: MTLTexture?, pass: MTLRenderPassDescriptor, context: EffectContext) -> Bool {
        let usesMips = context.motion * context.strength > 0
        var sampled = source
        if usesMips {
            guard let mips, let blit = command.makeBlitCommandEncoder() else { return false }
            blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .init(x: 0, y: 0, z: 0),
                      sourceSize: .init(width: source.width, height: source.height, depth: 1),
                      to: mips, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .init(x: 0, y: 0, z: 0))
            blit.generateMipmaps(for: mips)
            blit.endEncoding()
            sampled = mips
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        var uniforms = FrostUniforms(motion: Float(context.motion), finalFade: Float(context.finalFade), strength: Float(context.strength), pixel: SIMD2(1 / Float(source.width), 1 / Float(source.height)))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sampled, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FrostUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }
}
