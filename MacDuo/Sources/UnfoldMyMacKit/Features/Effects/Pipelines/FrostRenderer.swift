import AppKit
import MetalKit
import UnfoldMyMacCore

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
    private var busy = [Bool](repeating: false, count: GPUTuning.maximumFramesInFlight)
    private var mips = [MTLTexture?](repeating: nil, count: GPUTuning.maximumFramesInFlight)
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
        let drawableSize = CGSize(width: size.width * scale, height: size.height * scale)
        if drawableSize != metalView.drawableSize { releaseCapturedTextures() }
        metalView.frame = CGRect(origin: .zero, size: size)
        metalView.drawableSize = drawableSize
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
    func stop() { releaseCapturedTextures(); metalView.removeFromSuperview() }
    /// Wrapped capture textures and mip chains are sized to the display; drop them whenever that changes or the effect stops.
    private func releaseCapturedTextures() {
        frame = nil
        mips = [MTLTexture?](repeating: nil, count: GPUTuning.maximumFramesInFlight)
        if let cache { CVMetalTextureCacheFlush(cache, 0) }
    }
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
