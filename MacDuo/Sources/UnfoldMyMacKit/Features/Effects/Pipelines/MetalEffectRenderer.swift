import AppKit
import MetalKit
import UnfoldMyMacCore

@MainActor private final class TransparentEffectView: MTKView {
    override var isOpaque: Bool { false }
}

@MainActor final class MetalEffectRenderer<Pipeline: MetalEffectPipeline>: NSObject, EffectRenderer, MTKViewDelegate {
    let metal: Pipeline
    private let metalView: MTKView
    var view: NSView { metalView }
    let ready = true
    var animatesWithTime: Bool { metal.animatesWithTime }
    private(set) var lastGPUTime = 0.0
    private var context = EffectContext(closure: 0)
    private var submittedContext: EffectContext?
    private var inFlight = 0

    init(pipeline: Pipeline) {
        metal = pipeline
        metalView = TransparentEffectView(frame: .zero, device: pipeline.gpu)
        super.init()
        metalView.colorPixelFormat = pipeline.pixelFormat
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = false
        metalView.framebufferOnly = true
        metalView.autoresizingMask = [.width, .height]
        metalView.delegate = self
        metalView.layer?.isOpaque = false
        (metalView.layer as? CAMetalLayer)?.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
    }
    func prepare(size: CGSize, scale: CGFloat) {
        metalView.frame = CGRect(origin: .zero, size: size)
        metalView.drawableSize = CGSize(width: size.width * scale, height: size.height * scale)
        submittedContext = nil
    }
    func update(_ context: EffectContext) {
        self.context = context
        if context != submittedContext { metalView.draw() }
    }
    func stop() { metalView.removeFromSuperview(); submittedContext = nil }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { submittedContext = nil }
    func draw(in view: MTKView) {
        guard inFlight < GPUTuning.maximumFramesInFlight, let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable, let command = metal.queue.makeCommandBuffer() else { return }
        guard metal.encode(command: command, pass: pass, size: view.drawableSize, context: context) else { return }
        submittedContext = context
        inFlight += 1
        command.present(drawable)
        command.addCompletedHandler { [weak self] buffer in
            let succeeded = buffer.status == .completed
            let time = max(0, buffer.gpuEndTime - buffer.gpuStartTime)
            Task { @MainActor in
                self?.inFlight -= 1
                self?.lastGPUTime = time
                if !succeeded { self?.submittedContext = nil }
            }
        }
        command.commit()
    }
}
