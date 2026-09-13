import SwiftUI
import UnfoldMyMacCore

struct WallpaperFeatureView: View {
    @Bindable var model: WallpaperModel
    var collection: ContentCollection = .wallpapers
    var body: some View {
        @Bindable var setup = model.setup
        NavigationStack {
            WallpaperPage(model: model, collection: collection)
                .navigationDestination(for: String.self) { id in
                    if let template = model.catalog.template(id) { WallpaperDetailPage(model: model, template: template) }
                }
        }
        .sheet(item: $setup.request, onDismiss: { setup.cancel() }) { request in
            WallpaperTemplateSetupSheet(setup: setup, request: request)
        }
    }
}
