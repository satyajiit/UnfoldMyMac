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

struct WallpaperPage: View {
    @Bindable var model: WallpaperModel
    @Environment(\.colorScheme) private var scheme
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

struct WallpaperTemplateCard: View {
    let template: WallpaperTemplate
    let image: NSImage?
    let selected: Bool
    let ready: Bool
    let action: () -> Void
    let configure: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
              VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if let image { Image(nsImage: image).resizable().scaledToFill() }
                    WallpaperLayers(template: template, snapshot: .init(), animated: false)
                }.aspectRatio(1.6, contentMode: .fit).clipped()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.title).font(UnfoldMyMacType.headline)
                        Spacer(minLength: 4)
                        IconGlyph(icon: selected ? .selected : .play, size: 13).foregroundStyle(selected ? p.accent : p.secondary)
                    }
                    Text(template.tags.joined(separator: " · ")).font(UnfoldMyMacType.caption).foregroundStyle(p.secondary).lineLimit(2)
                }.padding(14)
              }.contentShape(.rect)
            }
            .buttonStyle(.plain).accessibilityLabel("Preview \(template.title)")
            .accessibilityIdentifier("wallpaper.template.\(template.id)")
            HStack {
                Button(selected ? "Previewing" : "Preview", action: action).buttonStyle(.plain).foregroundStyle(p.accent)
                Spacer(minLength: 4)
                if !(template.setup ?? []).isEmpty {
                    Button(ready ? "Configure" : "Set up", action: configure)
                        .modifier(UnfoldMyMacButtonStyle()).accessibilityIdentifier("wallpaper.configure.\(template.id)")
                }
            }.font(UnfoldMyMacType.caption).padding(.horizontal, 14).padding(.bottom, 14)
        }
            .foregroundStyle(p.ink).background(p.card, in: .rect(cornerRadius: 14))
            .clipShape(.rect(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? p.accent : p.ink.opacity(0.10), lineWidth: selected ? 2 : 1) }
            .contentShape(.rect(cornerRadius: 14))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
