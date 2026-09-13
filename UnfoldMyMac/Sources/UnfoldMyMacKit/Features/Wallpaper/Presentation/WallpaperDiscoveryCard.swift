import SwiftUI
import UnfoldMyMacCore

/// Opening a discovery card never applies a design or changes connections.
struct WallpaperDiscoveryCard: View {
    let template: WallpaperTemplate
    let image: NSImage?
    let style: WallpaperStyle
    let applied: Bool
    var list = false
    var assets: WallpaperAssetResolver = .shared
    @Palette private var palette
    var body: some View {
        Group {
            if list {
                HStack(spacing: 16) {
                    artwork.frame(width: 150, height: 96).clipped().clipShape(.rect(cornerRadius: 10))
                    information
                    Image(systemName: "chevron.right").foregroundStyle(palette.secondary)
                }.padding(12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    artwork.aspectRatio(1.65, contentMode: .fit).clipped()
                    information.padding(14)
                }
            }
        }
        .foregroundStyle(palette.ink).background(palette.card).clipShape(.rect(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(applied ? palette.accent : palette.ink.opacity(0.12), lineWidth: applied ? 2 : 1) }
        .contentShape(.rect(cornerRadius: 15)).accessibilityElement(children: .combine)
        .accessibilityIdentifier("wallpaper.template.\(template.id)")
    }
    private var artwork: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: template.background)
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
                WallpaperLayers(template: template, snapshot: .init(), animated: false, styleSheet: style)
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if applied {
                Label("On your desktop", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium)).padding(7)
                    .foregroundStyle(.white).background(.black.opacity(0.75), in: .capsule).padding(10)
            }
        }.accessibilityHidden(true)
    }
    private var information: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(template.title).font(UnfoldMyMacType.headline).lineLimit(2)
                Spacer(minLength: 0)
                if let badge = template.metadata?.badge { ContentBadge(title: badge, highlighted: true) }
            }
            Text(template.subtitle).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                .lineLimit(list ? 1 : 2).frame(height: list ? nil : 32, alignment: .top)
            WallpaperCapabilityStrip(template: template, compact: true, assets: assets)
            HStack {
                Text("By \(template.contentAuthors.first?.name ?? template.author)")
                    .font(.system(size: 10)).foregroundStyle(palette.secondary).lineLimit(1)
                Spacer(minLength: 2)
                if !list { Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(palette.accent) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
