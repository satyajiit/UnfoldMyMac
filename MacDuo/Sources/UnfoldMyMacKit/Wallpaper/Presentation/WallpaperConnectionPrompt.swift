import SwiftUI

/// Status follows the preview's own template and connection scope.
struct WallpaperConnectionPrompt: View {
    let model: WallpaperModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selected = model.selected, !model.setup.isReady(selected) {
                Label("Set up this wallpaper's required connections before using it.", icon: .connection)
            }
            if let url = model.selected?.countdown?.sourceURL ?? model.selected?.informationURL {
                Link(model.selected?.countdown != nil ? "Official release details" : "About NOAA’s aurora forecast", destination: url)
            }
            ForEach((model.selected?.dataNamespaces ?? []).sorted(), id: \.self) { namespace in
                if let error = model.previewSnapshot.errors[namespace] {
                    Label(error, icon: .warning).fixedSize(horizontal: false, vertical: true)
                } else if let status = model.previewSnapshot.sources[namespace]?.status, namespace != "mac", namespace != "scene" {
                    Text(status).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
    }
}
