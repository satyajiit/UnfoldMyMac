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
    @Palette private var palette
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 0) {
                    EffectCover(url: effect.coverURL)
                        .aspectRatio(1.65, contentMode: .fit).clipped()
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(effect.title).font(UnfoldMyMacType.headline).foregroundStyle(palette.ink).lineLimit(1)
                            Spacer(minLength: 0)
                            if selected {
                                IconGlyph(icon: .selected, size: 14).foregroundStyle(palette.accent)
                            }
                        }
                        Text(effect.subtitle).font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                            .lineLimit(2).frame(height: 32, alignment: .top)
                        HStack(spacing: 6) {
                            ContentBadge(title: "Lid", symbol: "laptopcomputer")
                            if effect.requiresCapture { ContentBadge(title: "Screen capture", symbol: "record.circle") }
                            else if effect.hasContinuousMotion { ContentBadge(title: "Animated", symbol: "sparkles") }
                        }.padding(.vertical, 4)
                        Text("By \(effect.author)").font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary).lineLimit(1)
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

                Button(action: adjust) { Label("Customize", icon: .settings).labelStyle(.iconOnly) }
                    .modifier(UnfoldMyMacButtonStyle())
                    .accessibilityLabel("Adjust \(effect.title)")
                    .accessibilityIdentifier("effect.adjust.\(effect.id.rawValue)")
                    .help("Adjust \(effect.title)")
            }.padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(palette.card).clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? palette.accent : palette.ink.opacity(contrast == .increased ? 0.55 : 0.15), lineWidth: selected ? 2 : 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }
}
