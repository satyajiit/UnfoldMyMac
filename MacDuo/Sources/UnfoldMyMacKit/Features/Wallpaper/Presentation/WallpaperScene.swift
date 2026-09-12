import SwiftUI
import UnfoldMyMacCore

/// A scene inside the app window: the Metal surface under its text layers, posed from a snapshot.
struct WallpaperScene: View {
    let pipeline: WallpaperPipeline
    let snapshot: WallpaperSnapshot
    let fps: Int
    var styleSheet: WallpaperStyle = .standard
    var onStats: ((RenderStats) -> Void)?
    var body: some View {
        ZStack {
            WallpaperMetalView(pipeline: pipeline, pose: WallpaperPose(template: pipeline.template, snapshot: snapshot), fps: fps, onStats: onStats)
            WallpaperLayers(template: pipeline.template, snapshot: snapshot, animated: fps > 1, styleSheet: styleSheet)
        }
        .background(Color(hex: pipeline.template.background))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
