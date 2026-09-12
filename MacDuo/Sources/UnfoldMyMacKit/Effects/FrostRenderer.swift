import AppKit
import MetalKit
import UnfoldMyMacCore

struct FrostUniforms {
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
            throw NSError(domain: AppIdentity.name, code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal is unavailable on this Mac."])
        }
        self.gpu = gpu; self.queue = queue
        guard let url = Bundle.module.url(forResource: "Frost", withExtension: "metal", subdirectory: "Shaders") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let library = try gpu.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
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

/// CVPixelBuffer and CVMetalTexture must both survive until the GPU finishes sampling them.
private final class GPUFrame: @unchecked Sendable {
    let frame: DesktopFrame
    let wrapped: CVMetalTexture
    let texture: MTLTexture
    init(frame: DesktopFrame, wrapped: CVMetalTexture, texture: MTLTexture) {
        self.frame = frame; self.wrapped = wrapped; self.texture = texture
    }
}

@MainActor final class FrostRenderer: NSObject, DesktopFrameConsuming, MTKViewDelegate {
    let metal: FrostPipeline
    let metalView: MTKView
    var view: NSView { metalView }
    var ready: Bool { frame != nil }
    private var cache: CVMetalTextureCache?
    private var frame: GPUFrame?
    private var context = EffectContext(closure: 0)
    private var busy = [false, false, false]
    private var mips: [MTLTexture?] = [nil, nil, nil]
    private(set) var submittedFrames = 0
    private(set) var skippedFrames = 0
    private(set) var lastGPUTime: Double = 0

    init(pipeline: FrostPipeline) {
        metal = pipeline
        metalView = MTKView(frame: .zero, device: metal.gpu)
        super.init()
        CVMetalTextureCacheCreate(nil, nil, metal.gpu, nil, &cache)
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = false
        metalView.framebufferOnly = true
        metalView.delegate = self
        metalView.autoresizingMask = [.width, .height]
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        (metalView.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
    }
    func prepare(size: CGSize, scale: CGFloat) {
        metalView.frame = CGRect(origin: .zero, size: size)
        metalView.drawableSize = CGSize(width: size.width * scale, height: size.height * scale)
    }
    func receive(_ frame: DesktopFrame) {
        guard let cache else { return }
        var wrapped: CVMetalTexture?
        let buffer = frame.buffer
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm_srgb,
            CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &wrapped)
        guard status == kCVReturnSuccess, let wrapped, let texture = CVMetalTextureGetTexture(wrapped) else { return }
        self.frame = GPUFrame(frame: frame, wrapped: wrapped, texture: texture)
    }
    func update(_ context: EffectContext) { self.context = context; metalView.draw() }
    func stop() { frame = nil; metalView.removeFromSuperview() }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let frame, let slot = busy.firstIndex(of: false) else { skippedFrames += 1; return }
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = metal.queue.makeCommandBuffer() else { return }
        if context.motion * context.strength > 0 && (mips[slot]?.width != frame.texture.width || mips[slot]?.height != frame.texture.height) {
            mips[slot] = metal.makeMips(source: frame.texture)
        }
        guard metal.encode(command: command, source: frame.texture, mips: mips[slot], pass: pass, context: context) else { return }
        busy[slot] = true
        submittedFrames += 1
        command.present(drawable)
        command.addCompletedHandler { [weak self, frame] buffer in
            withExtendedLifetime(frame) {}
            let duration = max(0, buffer.gpuEndTime - buffer.gpuStartTime)
            Task { @MainActor in
                self?.busy[slot] = false
                self?.lastGPUTime = duration
            }
        }
        command.commit()
    }
}
