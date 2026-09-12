import AppKit
import UnfoldMyMacCore

/// A wallpaper scene on a display-link-paced surface: targets come from the view, frames from the smoother.
@MainActor final class WallpaperSurfaceRenderer {
    let pipeline: WallpaperPipeline
    private let driver: DisplayLinkFrameDriver<WallpaperPipeline>
    private var smoother = WallpaperFrameSmoother()
    var surfaceView: MetalSurfaceView { driver.renderer.surfaceView }
    var onStats: ((RenderStats) -> Void)? {
        get { driver.onStats }
        set { driver.onStats = newValue }
    }
    var isPaused: Bool { driver.isPaused }
    var framesPerSecond: Int { driver.framesPerSecond }

    init(pipeline: WallpaperPipeline) {
        self.pipeline = pipeline
        driver = DisplayLinkFrameDriver(renderer: MetalSurfaceRenderer(pipeline: pipeline))
        driver.frameSource = { [unowned self] delta, animating in smoother.advance(delta: delta, animating: animating) }
    }
    func configure(energy: Double, fps: Int, channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) {
        smoother.setTargets(energy: energy, channels: channels, grid: grid)
        driver.configure(framesPerSecond: fps)
    }
    func stop() { driver.stop() }
}
