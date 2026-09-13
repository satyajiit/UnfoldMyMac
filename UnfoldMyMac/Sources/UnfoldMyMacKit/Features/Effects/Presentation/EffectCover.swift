import SwiftUI
import UnfoldMyMacCore

struct EffectCover: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var background: Color = Color(hex: 0x183338)
    @Environment(\.coverImages) private var covers
    @State private var image: NSImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background
                if let image {
                    Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { IconGlyph(icon: .image, size: 26).foregroundStyle(.white.opacity(0.8)) }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
        .task(id: url) {
            guard let url else { image = nil; return }
            image = covers.cached(url)
            guard image == nil else { return }
            let loaded = await covers.image(for: url)
            if !Task.isCancelled { image = loaded }
        }
    }
}
