import SwiftUI
import UnfoldMyMacCore

struct CollectionBanner: View {
    let collection: ContentCollection
    @Palette private var palette

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                ContentBadge(title: collection == .scenes ? "New · Creative Scenes" : "Made for your desktop", highlighted: true)
                Text(collection == .scenes ? "Scenes that respond." : "A living desktop.")
                    .font(.system(size: 23, weight: .semibold)).tracking(-0.6)
                    .foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
                Text(collection == .scenes ? "Explore worlds shaped by motion and sound." : "Art and live information, drawn into your day.")
                    .font(UnfoldMyMacType.callout).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            EffectCover(url: BundleResources.image(collection.banner, folder: "Discovery"), contentMode: .fit, background: .clear)
                .padding(.vertical, 10).padding(.trailing, 18).frame(maxWidth: .infinity)
        }
        .frame(height: 160).background(palette.card)
        .clipShape(.rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(palette.ink.opacity(0.08)) }
        .accessibilityElement(children: .combine)
    }
}
