import SwiftUI
import UnfoldMyMacCore

struct WallpaperPage: View {
    @Bindable var model: WallpaperModel
    var body: some View {
        ScrollViewReader { scroll in
        FeaturePage(title: "Wallpaper") {
            HStack(spacing: 24) {
                PageHeading(title: "Wallpaper", subtitle: "A desktop with a life of its own.")
                Spacer(minLength: 0)
                NavigationLink { WallpaperSettingsPage(model: model) } label: {
                    Label("Playback settings", icon: .settings)
                }.modifier(UnfoldMyMacButtonStyle()).fixedSize().accessibilityIdentifier("wallpaper.settings")
            }
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                WallpaperPreviewCard(model: model).id("wallpaper.preview")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Living collection").font(UnfoldMyMacType.title2)
                        Text("Real-time scenes. Real data. Your kind of energy.").modifier(SecondaryTextStyle())
                    }
                    Spacer()
                    Button { WallpaperFileActions.importTemplate(model) } label: { Label("Import template", icon: .folder) }
                        .modifier(UnfoldMyMacButtonStyle()).accessibilityIdentifier("wallpaper.import")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    ForEach(model.templates) { template in
                        WallpaperTemplateCard(template: template, image: model.thumbnails[template.id], selected: model.selectedID == template.id,
                            ready: model.setup.isReady(template), action: { model.select(template.id) }, configure: {
                                model.select(template.id); model.setup.open(template)
                            })
                    }
                }
                if let error = model.error { ErrorCard(message: error, needsPermission: false) }
            }
        }
        .onChange(of: model.selectedID) { _, _ in scroll.scrollTo("wallpaper.preview", anchor: .top) }
        }
    }
}
