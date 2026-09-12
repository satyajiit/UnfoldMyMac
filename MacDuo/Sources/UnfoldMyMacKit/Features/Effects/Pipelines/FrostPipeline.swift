import Metal
import UnfoldMyMacCore

private struct FrostUniforms {
    var motion: Float
    var finalFade: Float
    var strength: Float
    var pad: Float = 0
    var pixel: SIMD2<Float>
    var padding: SIMD2<Float> = .zero
}

/// The desktop stays in place under a blur that deepens toward the hinge. Fed by screen capture.
@MainActor final class FrostPipeline: EffectPipeline, DesktopFrameSink {
    let gpu: GPUContext
    let surface = SurfaceConfiguration(pixelFormat: .bgra8Unorm_srgb, isOpaque: true, clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1))
    private let pipeline: MTLRenderPipelineState
    private let captures: CaptureTextureCache
    private var frame: CapturedTexture?
    /// One mip chain, rebuilt when the capture size changes; the queue serialises frames that share it.
    private var mips: MTLTexture?
    private(set) var contentGeneration = 0
    var isReady: Bool { frame != nil }

    init(gpu: GPUContext) throws {
        self.gpu = gpu
        captures = CaptureTextureCache(device: gpu.device)
        pipeline = try gpu.pipeline(.effect("Frost"), vertex: "frostVertex", fragment: "frostFragment", color: .bgra8Unorm_srgb)
    }
    func receive(_ frame: DesktopFrame) {
        guard let captured = captures.texture(for: frame, pixelFormat: .bgra8Unorm_srgb) else { return }
        self.frame = captured
        contentGeneration &+= 1
    }
    func prepare(size: CGSize) { releaseCapturedTextures() }
    func didStop() { releaseCapturedTextures() }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame context: EffectContext) -> Bool {
        guard let frame else { return false }
        // The pixel buffer must survive until the GPU has sampled it, even if a newer frame replaces it now.
        command.addCompletedHandler { _ in withExtendedLifetime(frame) {} }
        return encode(command: command, source: frame.texture, pass: pass, context: context)
    }
    /// Shared by the live surface and deterministic offscreen tests.
    func encode(command: MTLCommandBuffer, source: MTLTexture, pass: MTLRenderPassDescriptor, context: EffectContext) -> Bool {
        var sampled = source
        if context.motion * context.strength > 0 {
            if mips?.width != source.width || mips?.height != source.height { mips = makeMips(source: source) }
            guard let mips, let blit = command.makeBlitCommandEncoder() else { return false }
            blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .init(x: 0, y: 0, z: 0),
                      sourceSize: .init(width: source.width, height: source.height, depth: 1),
                      to: mips, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .init(x: 0, y: 0, z: 0))
            blit.generateMipmaps(for: mips)
            blit.endEncoding()
            sampled = mips
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        var uniforms = FrostUniforms(motion: Float(context.motion), finalFade: Float(context.finalFade), strength: Float(context.strength),
                                     pixel: SIMD2(1 / Float(source.width), 1 / Float(source.height)))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(sampled, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FrostUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }
    private func makeMips(source: MTLTexture) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: source.width, height: source.height, mipmapped: true)
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]
        return gpu.device.makeTexture(descriptor: descriptor)
    }
    /// Wrapped capture textures and the mip chain are sized to the display; drop them when that changes or the effect stops.
    private func releaseCapturedTextures() {
        frame = nil; mips = nil
        captures.flush()
    }
}
