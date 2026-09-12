import SwiftUI
import UnfoldMyMacCore

@MainActor private enum CoverCache {
    static let images = NSCache<NSURL, NSImage>()
}

struct EffectCover: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: NSImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: 0x183338)
                if let image {
                    Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { IconGlyph(icon: .image, size: 26).foregroundStyle(.white.opacity(0.8)) }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            guard let url else { return }
            CoverCache.images.countLimit = 80
            if let cached = CoverCache.images.object(forKey: url as NSURL) { image = cached; return }
            let thumbnail = await Task.detached(priority: .utility) { ImageFiles.thumbnail(at: url) }.value
            guard !Task.isCancelled, let thumbnail else { return }
            let result = NSImage(cgImage: thumbnail, size: .zero)
            CoverCache.images.setObject(result, forKey: url as NSURL)
            image = result
        }
    }
}
