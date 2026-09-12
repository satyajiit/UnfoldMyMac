import SwiftUI
import UnfoldMyMacCore

struct WallpaperTemplateCard: View {
    let template: WallpaperTemplate
    let image: NSImage?
    let selected: Bool
    let ready: Bool
    var imported = false
    var warnings: [WallpaperTemplateWarning] = []
    let action: () -> Void
    let configure: () -> Void
    var rename: () -> Void = {}
    var remove: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
              VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if let image { Image(nsImage: image).resizable().scaledToFill() }
                    WallpaperLayers(template: template, snapshot: .init(), animated: false)
                }.aspectRatio(template.canvasSize.width / template.canvasSize.height, contentMode: .fit).clipped()
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
                if !warnings.isEmpty {
                    IconGlyph(icon: .warning, size: 13).foregroundStyle(p.secondary)
                        .help(warnings.map(\.message).joined(separator: "\n")).accessibilityLabel("\(warnings.count) template warnings")
                }
                if !(template.setup ?? []).isEmpty {
                    Button(ready ? "Configure" : "Set up", action: configure)
                        .modifier(UnfoldMyMacButtonStyle()).accessibilityIdentifier("wallpaper.configure.\(template.id)")
                }
                if imported {
                    Menu {
                        Button { rename() } label: { Label("Rename…", icon: .rename) }
                        Button(role: .destructive) { remove() } label: { Label("Remove", icon: .trash) }
                    } label: { Label("More", icon: .more) }
                    .labelStyle(.iconOnly).menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("More actions for \(template.title)").accessibilityIdentifier("wallpaper.more.\(template.id)")
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
