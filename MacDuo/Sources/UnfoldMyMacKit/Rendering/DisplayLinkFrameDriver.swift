import QuartzCore

/// Paces a surface renderer with `CAMetalDisplayLink`: the link hands over each drawable and its target
/// time, the frame source turns elapsed time into a frame, and presentation timestamps feed the stats.
/// The link pauses while the window is fully occluded (P9) or the rate is zero.
/// `@preconcurrency`: the link is added to the main run loop, so its callback is main-thread by construction;
/// the conformance lets the compiler enforce that isolation at runtime instead of hiding the non-Sendable update.
@MainActor final class DisplayLinkFrameDriver<Pipeline: MetalPipeline>: NSObject, @preconcurrency CAMetalDisplayLinkDelegate {
    let renderer: MetalSurfaceRenderer<Pipeline>
    /// Produces the next frame from the seconds since the previous one; `animating` is false at 1 fps or below.
    var frameSource: ((_ delta: Double, _ animating: Bool) -> Pipeline.Frame)?
    var onStats: ((RenderStats) -> Void)?
    private var link: CAMetalDisplayLink?
    private(set) var framesPerSecond = 0
    private var occluded = false
    private var lastPresentation = 0.0, sampleStart = 0.0
    var isPaused: Bool { link?.isPaused ?? true }

    init(renderer: MetalSurfaceRenderer<Pipeline>) {
        self.renderer = renderer
        super.init()
        let link = CAMetalDisplayLink(metalLayer: renderer.layer)
        link.delegate = self
        link.preferredFrameLatency = 2
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link
        renderer.surfaceView.onVisibilityChanged = { [weak self] visible in
            guard let self, occluded == visible else { return }
            occluded = !visible; applyPause()
        }
    }
    isolated deinit { stop() }

    func configure(framesPerSecond fps: Int) {
        guard framesPerSecond != fps else { return }
        framesPerSecond = fps
        let rate = Float(max(1, fps))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
        lastPresentation = 0; sampleStart = 0; renderer.metrics.reset()
        applyPause()
    }
    func stop() {
        link?.invalidate(); link = nil
        renderer.surfaceView.onVisibilityChanged = nil
        onStats = nil; frameSource = nil; framesPerSecond = 0
        renderer.stop()
    }
    private func applyPause() { link?.isPaused = framesPerSecond == 0 || occluded }

    func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) { tick(update) }
    private func tick(_ update: CAMetalDisplayLink.Update) {
        let timestamp = update.targetPresentationTimestamp
        let delta = lastPresentation > 0 ? min(0.25, max(0, timestamp - lastPresentation)) : 0
        lastPresentation = timestamp
        guard let frameSource else { return }
        let frame = frameSource(delta, framesPerSecond > 1)
        let metrics = renderer.metrics
        renderer.draw(frame, into: update.drawable, presented: { metrics.presented(at: $0) })
        if sampleStart == 0 { sampleStart = timestamp }
        if timestamp - sampleStart >= 1 {
            let size = update.drawable.texture
            onStats?(metrics.sample(width: size.width, height: size.height))
            sampleStart = timestamp
        }
    }
}
