import AppKit
import UnfoldMyMacCore

/// A wallpaper scene on a display-link-paced surface: targets come from the view, frames from the smoother.
@MainActor final class WallpaperSurfaceRenderer {
    let pipeline: WallpaperPipeline
    private let driver: DisplayLinkFrameDriver<WallpaperPipeline>
    private var smoother: WallpaperFrameSmoother
    private let inputs: WallpaperInputService?
    private let consumerID = UUID()
    var surfaceView: MetalSurfaceView { driver.renderer.surfaceView }
    var onStats: ((RenderStats) -> Void)? {
        get { driver.onStats }
        set { driver.onStats = newValue }
    }
    var isPaused: Bool { driver.isPaused }
    var framesPerSecond: Int { driver.framesPerSecond }

    init(pipeline: WallpaperPipeline, inputs: WallpaperInputService? = nil) {
        self.inputs = pipeline.usesLiveInputs ? inputs : nil
        self.pipeline = pipeline
        smoother = WallpaperFrameSmoother(template: pipeline.template)
        driver = DisplayLinkFrameDriver(renderer: MetalSurfaceRenderer(pipeline: pipeline))
        driver.frameSource = { [unowned self] delta, animating in
            if let inputs = self.inputs { smoother.targetLiveInputs = inputs.inputs(for: pipeline.template.id, screenFrame: surfaceView.window?.screen?.frame) }
            return smoother.advance(delta: delta, animating: animating)
        }
        driver.onActivityChanged = { [weak self] active in
            guard let self else { return }
            // The driver already combines the view’s visibility report with the playback rate.
            let visible = active && surfaceView.window != nil
            self.inputs?.setConsumer(consumerID, template: pipeline.template.id, visible: visible, animated: framesPerSecond > 1)
        }
    }
    func configure(_ pose: WallpaperPose, framesPerSecond: Int) {
        smoother.setTargets(energy: pose.energy, channels: pose.channels, grid: pose.grid)
        smoother.targetLiveInputs = pose.liveInputs
        driver.configure(framesPerSecond: framesPerSecond)
    }
    func stop() { inputs?.removeConsumer(consumerID); driver.stop() }
    isolated deinit { inputs?.removeConsumer(consumerID) }
}
