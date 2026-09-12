import MetalKit
import SwiftUI
import UnfoldMyMacCore

struct WallpaperMetalView: NSViewRepresentable {
    let pipeline: WallpaperPipeline
    let energy: Double
    let fps: Int
    var grid: WallpaperScalarGrid? = nil
    var channels = SIMD4<Float>.zero
    var onStats: ((WallpaperRenderStats) -> Void)?
    func makeCoordinator() -> WallpaperMetalRenderer { WallpaperMetalRenderer(pipeline: pipeline) }
    func makeNSView(context: Context) -> WallpaperMetalSurface { context.coordinator.view }
    func updateNSView(_ nsView: WallpaperMetalSurface, context: Context) {
        context.coordinator.onStats = onStats
        context.coordinator.configure(energy: energy, fps: fps, channels: channels, grid: grid)
    }
    static func dismantleNSView(_ view: WallpaperMetalSurface, coordinator: WallpaperMetalRenderer) { coordinator.stop() }
}
