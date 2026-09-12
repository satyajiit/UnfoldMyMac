import SwiftUI
import UnfoldMyMacCore

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
struct UnfoldMyMacPalette {
    let dark: Bool
    var canvas: Color { Color(hex: dark ? UnfoldMyMacColors.darkCanvas : UnfoldMyMacColors.lightCanvas) }
    var card: Color { Color(hex: dark ? UnfoldMyMacColors.darkCard : UnfoldMyMacColors.lightCard) }
    var ink: Color { Color(hex: dark ? UnfoldMyMacColors.darkInk : UnfoldMyMacColors.lightInk) }
    var secondary: Color { Color(hex: dark ? UnfoldMyMacColors.darkSecondary : UnfoldMyMacColors.lightSecondary) }
    var controlAccent: Color { Color(hex: dark ? UnfoldMyMacColors.darkControlAccent : UnfoldMyMacColors.lightAccent) }
    var accent: Color { Color(hex: dark ? UnfoldMyMacColors.darkAccent : UnfoldMyMacColors.lightAccent) }
}

struct ContentCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder var content: () -> Content
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        content().padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(p.ink.opacity(contrast == .increased ? 0.55 : 0.08), lineWidth: 1) }
    }
}
struct PageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(UnfoldMyMacType.title).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(UnfoldMyMacType.body).modifier(SecondaryTextStyle())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct ParameterRow: View {
    let title: String
    let valueLabel: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title); Spacer(); Text(valueLabel).monospacedDigit().modifier(SecondaryTextStyle()) }
            Group {
                if let step { Slider(value: $value, in: range, step: step) }
                else { Slider(value: $value, in: range) }
            }.accessibilityLabel(title).accessibilityValue(valueLabel)
        }
    }
}
struct StatusIndicator: View {
    let text: String
    let enabled: Bool
    var body: some View {
        Label(text, icon: enabled ? .selected : .idle)
            .font(UnfoldMyMacType.callout).lineLimit(2).accessibilityElement(children: .combine)
    }
}
struct UnfoldMyMacButtonStyle: ViewModifier {
    var prominent = false
    func body(content: Content) -> some View {
        content.buttonStyle(UnfoldMyMacActionButtonStyle(prominent: prominent))
    }
}

/// Render the label ourselves: macOS's tinted glass primitive can recolor an
/// inherited foreground to cyan, even when a white foreground is requested.
private struct UnfoldMyMacActionButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        configuration.label
            .font(UnfoldMyMacType.callout)
            .foregroundStyle(isEnabled ? (prominent ? Color.white : p.ink) : p.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minHeight: 30)
            .background {
                if prominent && isEnabled {
                    Capsule().fill(p.controlAccent).brightness(configuration.isPressed ? -0.08 : 0)
                } else if reduceTransparency || !isEnabled {
                    Capsule().fill(p.card)
                } else {
                    Capsule().fill(.clear).glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .overlay {
                Capsule().strokeBorder(isFocused ? p.accent : (prominent ? Color.white.opacity(0.12) : p.ink.opacity(0.15)),
                                       lineWidth: isFocused ? 2 : 1)
            }
            .contentShape(.capsule)
    }
}
struct ErrorCard: View {
    let message: String
    var needsPermission: Bool
    var body: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("A little setup is needed", icon: .warning).font(UnfoldMyMacType.headline)
                Text(message).font(UnfoldMyMacType.callout).fixedSize(horizontal: false, vertical: true)
                if needsPermission {
                    Button("Open Screen Recording Settings", action: { UnfoldMyMacModel.openScreenRecordingSettings() }).modifier(UnfoldMyMacButtonStyle())
                }
            }
        }.accessibilityElement(children: .contain)
    }
}

struct SecondaryTextStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.foregroundStyle(UnfoldMyMacPalette(dark: scheme == .dark).secondary)
    }
}
