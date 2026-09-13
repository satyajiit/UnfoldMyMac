import SwiftUI

/// Root of the desktop windows' text layers: reads the surface model, never the feature model.
struct WallpaperLayersRoot: View {
    let surface: WallpaperSurfaceModel
    var inputs: WallpaperInputService? = nil
    var body: some View {
        if let template = surface.template {
            ZStack {
                WallpaperLayers(template: template, snapshot: surface.snapshot, animated: surface.animated, styleSheet: surface.styleSheet)
                if template.id == "hinge-garden", let inputs { WallpaperGardenQuote(inputs: inputs) }
            }.ignoresSafeArea().allowsHitTesting(false)
        }
    }
}
