import SwiftUI
import UnfoldMyMacCore

/// Shared composition for the actual desktop, inline previews and thumbnail renders.
struct WallpaperScene: View {
    let pipeline: WallpaperPipeline
    let snapshot: WallpaperSnapshot
    let fps: Int
    var onStats: ((WallpaperRenderStats) -> Void)?
    var body: some View {
        ZStack {
            WallpaperMetalView(pipeline: pipeline,
                energy: (snapshot.number(pipeline.template.reactiveMetric) ?? 0)/pipeline.template.reactiveScale,
                fps: fps, grid: pipeline.template.gridBinding.flatMap { snapshot.grid($0) }, channels: channels, onStats: onStats)
            WallpaperLayers(template: pipeline.template, snapshot: snapshot, animated: fps > 1)
        }
        .background(Color(hex: pipeline.template.background))
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    private var channels: SIMD4<Float> {
        var values = SIMD4<Float>.zero
        for (index, binding) in (pipeline.template.channels ?? []).prefix(4).enumerated() {
            values[index] = Float(min(1, max(0, (snapshot.number(binding.metric) ?? 0)/binding.scale)))
        }
        return values
    }
}
