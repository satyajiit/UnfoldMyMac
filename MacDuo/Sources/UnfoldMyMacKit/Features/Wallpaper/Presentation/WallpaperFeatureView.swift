import SwiftUI
import UnfoldMyMacCore

struct WallpaperFeatureView: View {
    @Bindable var model: WallpaperModel
    var body: some View {
        @Bindable var setup = model.setup
        NavigationStack {
            WallpaperPage(model: model)
        }
        .onAppear { model.setBrowsing(true) }
        .onDisappear { model.setBrowsing(false) }
        .sheet(item: $setup.request, onDismiss: { setup.cancel() }) { request in
            WallpaperTemplateSetupSheet(setup: setup, request: request)
        }
    }
}
