import SwiftUI
import UnfoldMyMacCore

struct WallpaperPage: View {
    @Bindable var model: WallpaperModel
    var collection: ContentCollection = .wallpapers
    @State private var query = ""
    @State private var category: String?
    @State private var tag: String?
    @State private var renaming: WallpaperTemplate?
    @State private var removing: WallpaperTemplate?
    @State private var newTitle = ""
    @AppStorage("unfoldmymac.discovery.list") private var list = false
    @Environment(\.filePicker) private var filePicker
    @Palette private var palette
    private var templates: [WallpaperTemplate] { model.templates.filter { $0.contentCollection == collection } }
    private var categories: [WallpaperCollection.Section] { model.catalog.collection.sections(templates) }
    private var availableTags: [String] {
        Array(Set(templates.filter { category == nil || model.catalog.collection.category(for: $0).id == category }.flatMap(\.tags))).sorted()
    }
    private var filtered: [WallpaperTemplate] {
        templates.filter {
            (category == nil || model.catalog.collection.category(for: $0).id == category) && $0.matchesDiscovery(query: query, tag: tag)
        }
    }
    var body: some View {
        FeaturePage(title: collection.title) {
            HStack {
                PageHeading(title: collection.title, subtitle: collection.subtitle)
                Spacer(minLength: 4)
                NavigationLink { WallpaperSettingsPage(model: model) } label: {
                    Label("Playback", icon: .settings)
                }.modifier(UnfoldMyMacButtonStyle()).fixedSize().accessibilityIdentifier("wallpaper.settings")
            }
        } content: {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                CollectionBanner(collection: collection)
                if model.enabled { activeDesktop }
                Section {
                    HStack(spacing: 12) {
                        CatalogSearchField(query: $query)
                        Picker("View", selection: $list) {
                            Image(systemName: "square.grid.2x2").tag(false).accessibilityLabel("Grid view")
                            Image(systemName: "list.bullet").tag(true).accessibilityLabel("List view")
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 76).accessibilityIdentifier("catalog.layout")
                    }
                    CatalogTagFilters(tags: availableTags, selection: $tag)
                    HStack {
                        Text("\(filtered.count) \(filtered.count == 1 ? "design" : "designs")").foregroundStyle(palette.secondary)
                        if !query.isEmpty || tag != nil || category != nil {
                            Button("Clear filters") { query = ""; tag = nil; category = nil }.buttonStyle(.plain).foregroundStyle(palette.accent)
                        }
                        Spacer()
                        Button {
                            filePicker.pick(WallpaperFileRequests.template) { url in if let url { model.importTemplate(url) } }
                        } label: { Label("Import design", systemImage: "plus") }
                            .buttonStyle(.plain).foregroundStyle(palette.accent).accessibilityIdentifier("wallpaper.import")
                    }.font(UnfoldMyMacType.caption)
                    if filtered.isEmpty {
                        ContentUnavailableView("No designs found", systemImage: "magnifyingglass",
                            description: Text("Try a different title, creator, or tag."))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: list ? 500 : 240), spacing: 16)], spacing: 16) {
                            ForEach(filtered) { template in
                                NavigationLink(value: template.id) {
                                    WallpaperDiscoveryCard(template: template, image: model.thumbnails[template.id], style: model.catalog.style,
                                        applied: model.enabled && model.preferences.templateID == template.id, list: list, assets: model.catalog.assets(for: template.id))
                                }.buttonStyle(.plain)
                                    .accessibilityHint("Open design details, preview, and setup.")
                                    .contextMenu { importedActions(template) }
                            }
                        }
                    }
                } header: { categoryTabs }
                if let error = model.error { ErrorCard(message: error, needsPermission: false) }
            }
        }
        .onChange(of: category) { _, _ in tag = nil }
        .alert("Rename design", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { template in
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") { model.renameTemplate(template.id, title: newTitle); renaming = nil }
        }
        .alert("Remove this design?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), presenting: removing) { template in
            Button("Cancel", role: .cancel) { removing = nil }
            Button("Remove", role: .destructive) { model.removeTemplate(template.id); removing = nil }
        } message: { template in Text("Removes the app’s copy of “\(template.title)”. Your original file is kept.") }
    }
    private var categoryTabs: some View {
        CatalogCategoryTabs(categories: categories.map(\.id), title: { id in
            categories.first { $0.id == id }?.category.title ?? id
        }, selection: $category)
    }
    private var activeDesktop: some View {
        HStack {
            Label(model.activeTitle, systemImage: "checkmark.circle.fill").foregroundStyle(palette.accent)
            Text("On your desktop").foregroundStyle(palette.secondary)
            Spacer()
            Button("Stop", action: model.stopWallpaper).buttonStyle(.plain).accessibilityIdentifier("wallpaper.stop")
        }.font(UnfoldMyMacType.caption).padding(12).background(palette.card, in: .rect(cornerRadius: 10))
    }
    @ViewBuilder private func importedActions(_ template: WallpaperTemplate) -> some View {
        if model.catalog.isImported(template.id) {
            Button("Rename…") { newTitle = template.title; renaming = template }
            Button("Remove…", role: .destructive) { removing = template }
        }
    }
}
