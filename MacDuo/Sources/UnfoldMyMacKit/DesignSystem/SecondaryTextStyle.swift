import SwiftUI
import UnfoldMyMacCore

struct SecondaryTextStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.foregroundStyle(UnfoldMyMacPalette(dark: scheme == .dark).secondary)
    }
}
