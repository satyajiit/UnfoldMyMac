import SwiftUI

/// Root of the desktop windows' text layers: reads the surface model, never the feature model.
struct WallpaperLayersRoot: View {
    let surface: WallpaperSurfaceModel
    var body: some View {
        if let template = surface.template {
            WallpaperLayers(template: template, snapshot: surface.snapshot, animated: surface.animated)
                .ignoresSafeArea().allowsHitTesting(false)
        }
    }
}
