import SwiftUI
import UnfoldMyMacCore

struct WallpaperPage: View {
    @Bindable var model: WallpaperModel
    @State private var renaming: WallpaperTemplate?
    @State private var removing: WallpaperTemplate?
    @State private var newTitle = ""
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
                ForEach(model.catalog.collection.sections(model.templates)) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(section.category.title).font(UnfoldMyMacType.headline)
                            Text("\(section.templates.count)").font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                            ForEach(section.templates) { template in
                                WallpaperTemplateCard(template: template, image: model.thumbnails[template.id], selected: model.selectedID == template.id,
                                    ready: model.setup.isReady(template), imported: model.catalog.isImported(template.id),
                                    warnings: model.catalog.warnings[template.id] ?? [],
                                    action: { model.select(template.id) },
                                    configure: { model.select(template.id); model.setup.open(template) },
                                    rename: { newTitle = template.title; renaming = template },
                                    remove: { removing = template })
                            }
                        }
                    }
                }
                if let error = model.error { ErrorCard(message: error, needsPermission: false) }
            }
        }
        .onChange(of: model.selectedID) { _, _ in scroll.scrollTo("wallpaper.preview", anchor: .top) }
        .alert("Rename wallpaper", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { template in
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") { model.renameTemplate(template.id, title: newTitle); renaming = nil }
        } message: { _ in Text("The name shown in your collection. The template file itself is not changed.") }
        .alert("Remove this wallpaper?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), presenting: removing) { template in
            Button("Cancel", role: .cancel) { removing = nil }
            Button("Remove", role: .destructive) { model.removeTemplate(template.id); removing = nil }
        } message: { template in Text("\(AppIdentity.name)’s copy of “\(template.title)” is deleted. The file you imported is not touched.") }
        }
    }
}
