import SwiftUI
import UnfoldMyMacCore

/// A scene inside the app window: the Metal surface under its text layers, posed from a snapshot.
struct WallpaperScene: View {
    let pipeline: WallpaperPipeline
    let snapshot: WallpaperSnapshot
    let fps: Int
    var styleSheet: WallpaperStyle = .standard
    var onStats: ((RenderStats) -> Void)?
    var inputs: WallpaperInputService? = nil
    var body: some View {
        ZStack {
            WallpaperMetalView(pipeline: pipeline, pose: WallpaperPose(template: pipeline.template, snapshot: snapshot), fps: fps, onStats: onStats, inputs: inputs)
            WallpaperLayers(template: pipeline.template, snapshot: snapshot, animated: fps > 1, styleSheet: styleSheet)
            WallpaperSceneOverlay(template: pipeline.template, snapshot: snapshot, inputs: inputs)
        }
        .background(Color(hex: pipeline.template.background))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
