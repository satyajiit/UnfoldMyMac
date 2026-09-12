import SwiftUI
import UnfoldMyMacCore

/// Selection and actions are sibling buttons, so every control has its own
/// keyboard target. Artwork never sits behind a label or a button.
struct EffectTile: View {
    let effect: EffectDescriptor
    let selected: Bool
    let previewing: Bool
    var select: () -> Void
    var preview: () -> Void
    var adjust: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 0) {
                    EffectCover(url: effect.coverURL)
                        .aspectRatio(3.0 / 2.0, contentMode: .fit).clipped()
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(effect.title).font(UnfoldMyMacType.headline).foregroundStyle(p.ink).lineLimit(1)
                            Spacer(minLength: 0)
                            if selected {
                                IconGlyph(icon: .selected, size: 14).foregroundStyle(p.accent)
                            }
                        }
                        Text("By \(effect.author)").font(UnfoldMyMacType.caption).foregroundStyle(p.secondary).lineLimit(1)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(effect.title), by \(effect.author), \(effect.tags.joined(separator: ", "))")
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityHint("Select this effect for your lid.")
            .accessibilityIdentifier("effect.\(effect.id.rawValue)")
            .help("Select \(effect.title). \(effect.subtitle)")

            HStack(spacing: 8) {
                Button(action: preview) {
                    Label(previewing ? "Stop" : "Preview", icon: previewing ? .stop : .play)
                        .frame(maxWidth: .infinity)
                }
                .modifier(UnfoldMyMacButtonStyle(prominent: true))
                .accessibilityLabel("\(previewing ? "Stop previewing" : "Preview") \(effect.title)")
                .accessibilityHint(effect.requiresCapture ? "Uses Screen Recording. Your selected effect stays unchanged." : "Try on your desktop without changing the selected effect.")
                .accessibilityIdentifier("effect.preview.\(effect.id.rawValue)")
                .help(previewing ? "Stop preview" : "Preview \(effect.title) on your desktop.\(effect.requiresCapture ? " Requires Screen Recording; frames stay on this Mac." : "")")

                Button(action: adjust) { Label("Adjust", icon: .settings).labelStyle(.iconOnly) }
                    .modifier(UnfoldMyMacButtonStyle())
                    .accessibilityLabel("Adjust \(effect.title)")
                    .accessibilityIdentifier("effect.adjust.\(effect.id.rawValue)")
                    .help("Adjust \(effect.title)")
            }.padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(p.card).clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? p.accent : p.ink.opacity(contrast == .increased ? 0.55 : 0.15), lineWidth: selected ? 2 : 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }
}

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
