import SwiftUI
import UnfoldMyMacCore

struct EffectsPage: View {
    @Bindable var model: UnfoldMyMacModel
    let showSettings: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var showingInspector = false
    @State private var previewAfterInspector: EffectID?
    @State private var categoriesPinned = false
    @State private var categoriesOrigin: CGFloat = 0
    private var availableTags: [String] { model.library.availableTags(in: model.registry.descriptors) }
    private var filtered: [EffectDescriptor] { model.library.filtered(model.registry.descriptors) }
    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { scroll in
                FeaturePage(title: "Effects", onScroll: { offset in
                    categoriesPinned = categoriesOrigin > 0 && offset >= categoriesOrigin - 1
                }) {
                    EffectsHeader(model: model, showSettings: showSettings)
                } content: {
                    library(minimumResultsHeight: max(0, viewport.size.height - 48))
                }
                .onChange(of: model.libraryCategory) { _, _ in
                    model.libraryTag = nil
                    if categoriesPinned {
                        scroll.scrollTo("library.categories", anchor: .top)
                    }
                }
            }
        }
        .sheet(isPresented: $showingInspector, onDismiss: {
            if let id = previewAfterInspector {
                previewAfterInspector = nil
                model.togglePreview(for: id)
            }
        }) {
            EffectInspector(model: model, preview: { previewAfterInspector = $0 })
        }
    }

    @ViewBuilder private func library(minimumResultsHeight: CGFloat) -> some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            HStack(spacing: 16) {
                Text("Design library").font(UnfoldMyMacType.title3)
                Spacer(minLength: 8)
                Button(action: model.chooseArtwork) { Label(model.isImporting ? "Adding…" : "Add image", icon: .importImage) }
                    .modifier(UnfoldMyMacButtonStyle(prominent: true))
                    .disabled(model.isImporting || model.artworkLibrary == nil)
                    .fixedSize().accessibilityIdentifier("library.import")
            }.padding(.bottom, 8)
            Color.clear.frame(height: 0).id("library.categories")
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.frame(in: .named("feature.content")).minY
                } action: { origin in
                    categoriesOrigin = origin
                }
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                IconGlyph(icon: .search, size: 14).foregroundStyle(p.secondary)
                                TextField("Search designs, tags, authors", text: $model.libraryQuery,
                                          prompt: Text("Search designs, tags, authors").foregroundStyle(p.secondary))
                                    .textFieldStyle(.plain).accessibilityIdentifier("library.search")
                                if !model.libraryQuery.isEmpty {
                                    Button { model.libraryQuery = "" } label: { Label("Clear search", icon: .clear) }
                                        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(p.secondary)
                                }
                            }.padding(10).background(p.card, in: .rect(cornerRadius: 10))
                            Picker("Tag", selection: $model.libraryTag) {
                                Text("All tags").tag(nil as String?)
                                ForEach(availableTags, id: \.self) { Text($0).tag(Optional($0)) }
                            }.labelsHidden().frame(width: 150).accessibilityIdentifier("library.tags")
                        }
                        HStack {
                            Text("\(filtered.count) \(filtered.count == 1 ? "design" : "designs")\(model.libraryTag.map { " · \($0)" } ?? "")")
                            if !model.libraryQuery.isEmpty || model.libraryTag != nil {
                                Button("Reset filters") { model.libraryQuery = ""; model.libraryTag = nil }
                                    .buttonStyle(.plain).foregroundStyle(p.accent)
                            }
                            Spacer(minLength: 8)
                            Text("Preview without changing your selection.")
                        }.font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
                    }
                    if model.isImporting {
                        HStack { ProgressView().controlSize(.small); Text("Preparing your image…").font(UnfoldMyMacType.callout) }
                    }
                    if let message = model.libraryMessage {
                        Label(message, icon: .warning).font(UnfoldMyMacType.callout).foregroundStyle(p.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if filtered.isEmpty {
                        ContentCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No designs found").font(UnfoldMyMacType.headline)
                                Text("Try another tag, title, or author.").foregroundStyle(p.secondary)
                            }
                        }
                    } else {
                        ForEach(EffectCategory.allCases) { category in
                            let designs = filtered.filter { $0.category == category }
                            if !designs.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    if model.libraryCategory == nil {
                                        HStack {
                                            Text(category.title).font(UnfoldMyMacType.headline)
                                            Text("\(designs.count)").font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
                                        }
                                    }
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
                                        ForEach(designs) { effect in
                                            EffectTile(effect: effect, selected: model.settings.effect == effect.id,
                                                previewing: model.isPreviewing && model.previewEffectID == effect.id,
                                                select: { model.selectEffect(effect.id) },
                                                preview: { model.togglePreview(for: effect.id) },
                                                adjust: { model.selectEffect(effect.id); showingInspector = true })
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let error = model.errorMessage { ErrorCard(message: error, needsPermission: model.needsPermission, openScreenRecordingSettings: model.openScreenRecordingSettings) }
                    if model.reduceTransparency {
                        Label("Reduce Transparency is on. Effects use a dim-only treatment.", icon: .accessibility)
                            .font(UnfoldMyMacType.callout).foregroundStyle(p.secondary)
                    }
                }
                // A short category still leaves room to keep its tabs pinned.
                .frame(minHeight: minimumResultsHeight, alignment: .top)
            } header: {
                categoryTabs
            }
        }
    }

    private var categoryTabs: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        return Picker("Collection", selection: $model.libraryCategory) {
            Text("All · \(model.registry.descriptors.count)").tag(nil as EffectCategory?)
            ForEach(EffectCategory.allCases) { category in
                Text(category.title).tag(Optional(category))
            }
        }
        .pickerStyle(.segmented).labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .background(p.canvas.padding(.horizontal, -28))
        .accessibilityIdentifier("library.category")
    }
}
