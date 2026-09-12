import MetalKit
import SwiftUI
import UnfoldMyMacCore

struct WallpaperMetalView: NSViewRepresentable {
    let pipeline: WallpaperPipeline
    let pose: WallpaperPose
    let fps: Int
    var onStats: ((RenderStats) -> Void)?
    func makeCoordinator() -> WallpaperSurfaceRenderer { WallpaperSurfaceRenderer(pipeline: pipeline) }
    func makeNSView(context: Context) -> MetalSurfaceView { context.coordinator.surfaceView }
    func updateNSView(_ nsView: MetalSurfaceView, context: Context) {
        context.coordinator.onStats = onStats
        context.coordinator.configure(pose, framesPerSecond: fps)
    }
    static func dismantleNSView(_ view: MetalSurfaceView, coordinator: WallpaperSurfaceRenderer) { coordinator.stop() }
}
