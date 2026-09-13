import SwiftUI

struct IconGlyph: View {
    let icon: UnfoldMyMacIcon
    var size: CGFloat = 16
    var body: some View {
        Image(systemName: icon.rawValue)
            .font(.system(size: size, weight: .medium))
            .frame(width: size + 4, height: size + 4)
            .accessibilityHidden(true)
    }
}
