import AppKit
import Metal
import QuartzCore

/// Owns the drawable lifecycle for one pipeline on one layer: in-flight accounting, the cached render pass,
/// metrics and the never-drop-a-drawable error path. Pacing is external: `render(_:)` draws on demand,
/// `DisplayLinkFrameDriver` draws on a display link.
@MainActor final class MetalSurfaceRenderer<Pipeline: MetalPipeline> {
    let pipeline: Pipeline
    let surfaceView: MetalSurfaceView
    let metrics = FrameMetrics()
    private(set) var submittedFrames = 0
    private(set) var skippedFrames = 0
    private let pass = MTLRenderPassDescriptor()
    private var lastSubmitted: (frame: Pipeline.Frame, generation: Int)?
    private var acknowledgedFailures = 0

    var view: NSView { surfaceView }
    var layer: CAMetalLayer { surfaceView.surfaceLayer }
    var lastGPUTime: Double { metrics.lastGPUSeconds }
    var isReady: Bool { pipeline.isReady }

    init(pipeline: Pipeline) {
        self.pipeline = pipeline
        let surface = pipeline.surface
        surfaceView = MetalSurfaceView(opaque: surface.isOpaque)
        let layer = surfaceView.surfaceLayer
        layer.device = pipeline.gpu.device
        layer.pixelFormat = surface.pixelFormat
        layer.framebufferOnly = true
        layer.isOpaque = surface.isOpaque
        layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        layer.presentsWithTransaction = false
        layer.displaySyncEnabled = true
        layer.maximumDrawableCount = GPUTuning.maximumFramesInFlight
        pass.colorAttachments[0].loadAction = surface.loadAction
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = surface.clearColor
        surfaceView.onLayout = { [weak self] in self?.layoutDrawable() }
    }

    /// Sizes the view and its drawable before the view has a window. A stopped renderer can be prepared again.
    func prepare(size: CGSize, scale: CGFloat) {
        surfaceView.onLayout = { [weak self] in self?.layoutDrawable() }
        surfaceView.frame = CGRect(origin: .zero, size: size)
        layer.contentsScale = scale
        setDrawableSize(Self.drawableSize(points: size, scale: scale, cap: pipeline.surface.maximumDimension))
    }
    /// Encodes and presents one frame now, unless an identical one is already on screen or the pool is full.
    @discardableResult func render(_ frame: Pipeline.Frame) -> Bool {
        let generation = pipeline.contentGeneration
        if let last = lastSubmitted, last.frame == frame, last.generation == generation, metrics.failures == acknowledgedFailures { return false }
        guard metrics.inFlight < GPUTuning.maximumFramesInFlight, layer.drawableSize.width > 0, layer.drawableSize.height > 0,
              let drawable = layer.nextDrawable() else { return false }
        lastSubmitted = (frame, generation); acknowledgedFailures = metrics.failures
        return draw(frame, into: drawable)
    }
    /// Encodes `frame` into a drawable the caller obtained. A pipeline that cannot encode still gets a cleared,
    /// presented drawable so a stale image never stays on screen (L6).
    @discardableResult func draw(_ frame: Pipeline.Frame, into drawable: any CAMetalDrawable, presented: (@Sendable (Double) -> Void)? = nil) -> Bool {
        guard let command = pipeline.gpu.queue.makeCommandBuffer() else { return false }
        let texture = drawable.texture
        pass.colorAttachments[0].texture = texture
        pass.depthAttachment.texture = nil
        let encoded = pipeline.encode(command: command, pass: pass, size: CGSize(width: texture.width, height: texture.height), frame: frame)
        if encoded { submittedFrames += 1 } else { skippedFrames += 1; encodeClear(command, texture: texture) }
        if let presented { drawable.addPresentedHandler { presented($0.presentedTime) } }
        command.present(drawable)
        let metrics = metrics
        metrics.began()
        command.addCompletedHandler { buffer in
            metrics.completed(gpuSeconds: buffer.gpuEndTime - buffer.gpuStartTime, succeeded: buffer.status == .completed)
        }
        command.commit()
        return encoded
    }
    /// Terminal: releases the pipeline's per-surface resources and every closure the view holds.
    func stop() {
        pipeline.didStop()
        lastSubmitted = nil
        surfaceView.onLayout = nil
        surfaceView.removeFromSuperview()
    }

    private func encodeClear(_ command: MTLCommandBuffer, texture: MTLTexture) {
        let clear = MTLRenderPassDescriptor()
        clear.colorAttachments[0].texture = texture
        clear.colorAttachments[0].loadAction = .clear
        clear.colorAttachments[0].storeAction = .store
        clear.colorAttachments[0].clearColor = pipeline.surface.clearColor
        command.makeRenderCommandEncoder(descriptor: clear)?.endEncoding()
    }
    private func layoutDrawable() {
        let size = surfaceView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = surfaceView.window?.backingScaleFactor ?? layer.contentsScale
        setDrawableSize(Self.drawableSize(points: size, scale: max(1, scale), cap: pipeline.surface.maximumDimension))
    }
    private func setDrawableSize(_ desired: CGSize) {
        guard layer.drawableSize != desired else { return }
        layer.drawableSize = desired
        lastSubmitted = nil
        pipeline.prepare(size: desired)
    }
    static func drawableSize(points: CGSize, scale: CGFloat, cap: Double?) -> CGSize {
        var scale = scale
        if let cap { scale = min(scale, cap / max(1, max(points.width, points.height))) }
        return CGSize(width: max(1, (points.width * scale).rounded()), height: max(1, (points.height * scale).rounded()))
    }
}
