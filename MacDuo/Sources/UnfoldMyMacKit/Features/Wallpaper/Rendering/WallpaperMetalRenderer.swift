import MetalKit
import SwiftUI
import UnfoldMyMacCore

@MainActor final class WallpaperMetalRenderer: NSObject, @preconcurrency CAMetalDisplayLinkDelegate {
    let pipeline: WallpaperPipeline
    let view = WallpaperMetalSurface(frame: .zero)
    var onStats: ((WallpaperRenderStats) -> Void)?
    private let metrics = WallpaperFrameMetrics()
    private var grid: WallpaperScalarGrid?
    private var displayLink: CAMetalDisplayLink!
    private var metalLayer: CAMetalLayer!
    private var targetEnergy = 0.0, energy = 0.0
    private var channels = SIMD4<Float>.zero, targetChannels = SIMD4<Float>.zero
    private var time = 0.0, lastPresentation = 0.0, sampleStart = 0.0
    private(set) var framesPerSecond = 0
    var isPaused: Bool { displayLink?.isPaused ?? true }

    init(pipeline: WallpaperPipeline) {
        self.pipeline = pipeline
        super.init()
        view.wantsLayer = true
        metalLayer = view.layer as? CAMetalLayer
        metalLayer.device = pipeline.catalog.gpu
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true; metalLayer.isOpaque = true
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        metalLayer.presentsWithTransaction = false; metalLayer.displaySyncEnabled = true
        metalLayer.maximumDrawableCount = GPUTuning.maximumFramesInFlight
        view.onLayout = { [weak self] in self?.resizeDrawable() }
        displayLink = CAMetalDisplayLink(metalLayer: metalLayer)
        displayLink.delegate = self; displayLink.preferredFrameLatency = 2
        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: .common)
    }
    func configure(energy: Double, fps: Int, channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) {
        targetEnergy = energy.isFinite ? min(1, max(0, energy)) : 0
        targetChannels = channels
        self.grid = grid
        guard framesPerSecond != fps else { return }
        framesPerSecond = fps
        let rate = Float(max(1, fps))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
        displayLink.isPaused = fps == 0
        lastPresentation = 0; sampleStart = 0; metrics.reset()
        resizeDrawable()
    }
    func stop() {
        displayLink?.invalidate(); displayLink = nil
        view.onLayout = nil; onStats = nil; framesPerSecond = 0
    }
    func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        let timestamp = update.targetPresentationTimestamp
        let delta = lastPresentation > 0 ? min(0.25, max(0, timestamp - lastPresentation)) : 0
        lastPresentation = timestamp
        if framesPerSecond > 1 {
            time += delta; energy += (targetEnergy - energy) * (1 - exp(-delta * 4))
            channels += (targetChannels - channels) * Float(1 - exp(-delta * 4))
        } else { energy = targetEnergy; channels = targetChannels }
        let drawable = update.drawable
        let size = CGSize(width: drawable.texture.width, height: drawable.texture.height)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .dontCare; pass.colorAttachments[0].storeAction = .store
        guard let command = pipeline.catalog.queue.makeCommandBuffer(),
              pipeline.encode(command: command, pass: pass, size: size, time: framesPerSecond > 1 ? time : 0,
                              energy: energy, channels: channels, grid: grid) else { return }
        let metrics = metrics
        drawable.addPresentedHandler { metrics.presented(at: $0.presentedTime) }
        command.addCompletedHandler { buffer in
            if buffer.status == .completed { metrics.completed(gpuSeconds: buffer.gpuEndTime - buffer.gpuStartTime) }
        }
        // CAMetalDisplayLink owns presentation timing for this drawable.
        command.present(drawable)
        command.commit()
        if sampleStart == 0 { sampleStart = timestamp }
        if timestamp - sampleStart >= 1 {
            onStats?(metrics.sample(width: Int(size.width), height: Int(size.height)))
            sampleStart = timestamp
        }
    }
    private func resizeDrawable() {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(view.window?.backingScaleFactor ?? 2, GPUTuning.maximumWallpaperDimension / max(size.width, size.height))
        let desired = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
        if metalLayer.drawableSize != desired { metalLayer.drawableSize = desired }
    }
}
