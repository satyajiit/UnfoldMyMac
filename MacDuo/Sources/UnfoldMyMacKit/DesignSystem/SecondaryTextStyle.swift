import SwiftUI
import UnfoldMyMacCore

struct SecondaryTextStyle: ViewModifier {
    @Palette private var palette
    func body(content: Content) -> some View {
        content.foregroundStyle(palette.secondary)
    }
}
