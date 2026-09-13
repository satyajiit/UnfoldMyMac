import SwiftUI
import UnfoldMyMacCore

struct WallpaperCapabilityStrip: View {
    let template: WallpaperTemplate
    var compact = false
    var assets: WallpaperAssetResolver = .shared
    @Palette private var palette
    var body: some View {
        ContentFlowLayout(spacing: 6) {
            ForEach(template.metadata?.relatedBrands ?? [], id: \.self) { brand in
                HStack(spacing: 5) {
                    if let url = assets.mark(brand) {
                        EffectCover(url: url, contentMode: .fit).frame(width: 16, height: 16).clipShape(.rect(cornerRadius: 4))
                    } else { Image(systemName: "app.connected.to.app.below.fill").accessibilityHidden(true) }
                    Text(brand).font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(palette.ink.opacity(0.06), in: .capsule)
                .help("Related product: \(brand). See details for how this design uses it.")
            }
            ForEach(template.contentCapabilities) { capability in
                if compact {
                    Image(systemName: capability.symbol).font(.system(size: 12))
                        .foregroundStyle(palette.secondary).frame(width: 25, height: 25)
                        .background(palette.ink.opacity(0.06), in: .circle)
                        .help(capability.title + ": " + capability.detail).accessibilityLabel(capability.title)
                } else {
                    ContentBadge(title: capability.title, symbol: capability.symbol).help(capability.detail)
                }
            }
        }
    }
}
