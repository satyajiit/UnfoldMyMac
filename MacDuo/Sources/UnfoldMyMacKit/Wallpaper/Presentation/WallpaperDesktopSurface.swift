import SwiftUI

struct WallpaperDesktopSurface: View {
    let model: WallpaperModel
    var body: some View {
        if let pipeline = model.activePipeline {
            WallpaperScene(pipeline: pipeline, snapshot: model.data.snapshot, fps: model.playback.framesPerSecond,
                onStats: model.receiveStats)
                .id(ObjectIdentifier(pipeline))
                .ignoresSafeArea()
        }
    }
}
