import MetalKit
import SwiftUI
import UnfoldMyMacCore

struct WallpaperMetalView: NSViewRepresentable {
    let pipeline: WallpaperPipeline
    let energy: Double
    let fps: Int
    var grid: WallpaperScalarGrid? = nil
    var channels = SIMD4<Float>.zero
    var onStats: ((RenderStats) -> Void)?
    func makeCoordinator() -> WallpaperSurfaceRenderer { WallpaperSurfaceRenderer(pipeline: pipeline) }
    func makeNSView(context: Context) -> MetalSurfaceView { context.coordinator.surfaceView }
    func updateNSView(_ nsView: MetalSurfaceView, context: Context) {
        context.coordinator.onStats = onStats
        context.coordinator.configure(energy: energy, fps: fps, channels: channels, grid: grid)
    }
    static func dismantleNSView(_ view: MetalSurfaceView, coordinator: WallpaperSurfaceRenderer) { coordinator.stop() }
}
