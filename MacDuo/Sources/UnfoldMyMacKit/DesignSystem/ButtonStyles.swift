import SwiftUI
import UnfoldMyMacCore

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
    @Palette private var palette
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(UnfoldMyMacType.callout)
            .foregroundStyle(isEnabled ? (prominent ? Color.white : palette.ink) : palette.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minHeight: 30)
            .background {
                if prominent && isEnabled {
                    Capsule().fill(palette.controlAccent).brightness(configuration.isPressed ? -0.08 : 0)
                } else if reduceTransparency || !isEnabled {
                    Capsule().fill(palette.card)
                } else {
                    Capsule().fill(.clear).glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .overlay {
                Capsule().strokeBorder(isFocused ? palette.accent : (prominent ? Color.white.opacity(0.12) : palette.ink.opacity(0.15)),
                                       lineWidth: isFocused ? 2 : 1)
            }
            .contentShape(.capsule)
    }
}
