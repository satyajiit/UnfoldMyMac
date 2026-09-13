import SwiftUI
import UnfoldMyMacCore

struct WallpaperDetailPage: View {
    @Bindable var model: WallpaperModel
    let template: WallpaperTemplate
    @State private var previewing = false
    @Environment(\.workspace) private var workspace
    @Palette private var palette
    private var authors: [ContentAuthor] { template.contentAuthors }
    private var applied: Bool { model.enabled && model.preferences.templateID == template.id }
    var body: some View {
        FeaturePage(title: template.title) {
            heading
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                Group {
                    if previewing {
                        WallpaperPreviewCard(model: model, showsControls: false)
                    } else {
                        Button { previewing = true } label: {
                            ZStack {
                                if let image = model.thumbnails[template.id] {
                                    Image(nsImage: image).resizable().scaledToFill()
                                    WallpaperLayers(template: template, snapshot: .init(), animated: false, styleSheet: model.catalog.style)
                                } else { Color(hex: template.background) }
                                Label("Preview live", systemImage: "play.circle.fill")
                                    .font(.system(size: 16, weight: .semibold)).padding(14)
                                    .foregroundStyle(.white).background(.black.opacity(0.8), in: .capsule)
                            }.aspectRatio(1.6, contentMode: .fit).clipped().clipShape(.rect(cornerRadius: 16))
                        }.buttonStyle(.plain).accessibilityIdentifier("wallpaper.detail.preview")
                    }
                }.frame(maxWidth: 640).frame(maxWidth: .infinity)
                actions
                HStack {
                    Text(previewing ? "Live preview · Your desktop changes only when you choose Use." : "Preview the real design before adding it to your desktop.")
                    Spacer()
                    if previewing { Button("Stop preview") { previewing = false }.buttonStyle(.plain).foregroundStyle(palette.accent) }
                }.font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                Divider()
                if let error = model.error { ErrorCard(message: error, needsPermission: false) }
                ContentDescription(overview: template.metadata?.overview ?? template.subtitle, sections: template.metadata?.sections ?? [])
                Divider()
                requirements
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Created by").font(UnfoldMyMacType.title3)
                    ForEach(Array(authors.enumerated()), id: \.offset) { _, author in
                        ContentAuthorRow(author: author, logoURL: author.logo.flatMap { model.catalog.assets(for: template.id).mark($0) })
                    }
                    if let credit = template.credit, !credit.isEmpty {
                        Text(credit).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if let url = template.informationURL, url.scheme == "https", url.host != nil {
                        Button { workspace.open(url) } label: { Label("Learn more at the source", systemImage: "arrow.up.right.square") }
                            .buttonStyle(.plain).foregroundStyle(palette.accent)
                    }
                }
                ContentFlowLayout {
                    ForEach(template.tags, id: \.self) { ContentBadge(title: $0) }
                }
                if let warnings = model.catalog.warnings[template.id], !warnings.isEmpty {
                    ContentCard {
                        ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                            Label(warning.message, systemImage: "exclamationmark.triangle").font(UnfoldMyMacType.caption)
                        }
                    }
                }
            }
        }
        .onAppear { model.select(template.id) }
        .onDisappear { model.setPreviewVisible(false) }
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.contentCollection.title).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                        if let badge = template.metadata?.badge { ContentBadge(title: badge, highlighted: true) }
                    }
                    Text(template.title).font(.system(size: 28, weight: .semibold)).tracking(-0.7)
                        .foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("wallpaper.detail.title")
                    Text(template.subtitle).font(UnfoldMyMacType.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            WallpaperCapabilityStrip(template: template, assets: model.catalog.assets(for: template.id))
            if let author = authors.first {
                ContentAuthorRow(author: author, logoURL: author.logo.flatMap { model.catalog.assets(for: template.id).mark($0) })
            }
        }
    }
    private var actions: some View {
        ContentFlowLayout(spacing: 10) {
            Button {
                if model.selectedID != template.id { model.select(template.id) }
                model.apply()
            } label: {
                Label(applied ? "On your desktop" : template.contentCollection.actionTitle, systemImage: applied ? "checkmark.circle.fill" : "desktopcomputer")
            }.modifier(UnfoldMyMacButtonStyle(prominent: !applied)).disabled(applied || model.previewPipeline == nil)
                .accessibilityIdentifier("wallpaper.apply")
            if !(template.setup ?? []).isEmpty {
                Button { model.setup.open(template) } label: { Label("Customize", systemImage: "slider.horizontal.3") }
                    .modifier(UnfoldMyMacButtonStyle()).accessibilityIdentifier("wallpaper.detail.customize")
            }
            Button(action: workspace.showDesktop) {
                Label("Show Desktop", systemImage: "rectangle.inset.filled")
            }
            .modifier(UnfoldMyMacButtonStyle())
            .help("Hide other apps and minimize UnfoldMyMac to see your desktop. Reopen apps from the Dock.")
            .accessibilityIdentifier("wallpaper.detail.showDesktop")
            if applied {
                Button("Stop", action: model.stopWallpaper).buttonStyle(.plain)
                    .frame(minHeight: 30).accessibilityIdentifier("wallpaper.stop")
            }
            if !model.setup.isReady(template) { ContentBadge(title: "Setup needed", symbol: "link").frame(minHeight: 30) }
        }
    }
    private var requirements: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Features & connections").font(UnfoldMyMacType.title3)
            if template.contentCapabilities.isEmpty {
                Label("Runs locally. No account or connection required.", systemImage: "checkmark.shield")
                    .font(UnfoldMyMacType.callout).foregroundStyle(palette.secondary)
            }
            ForEach(template.contentCapabilities) { capability in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: capability.symbol).frame(width: 24).foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(capability.title).font(UnfoldMyMacType.callout)
                        Text(capability.detail).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
