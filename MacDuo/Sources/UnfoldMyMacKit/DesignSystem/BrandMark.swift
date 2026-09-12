import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 28
    var body: some View {
        if let logo = BrandAssets.logo {
            Image(nsImage: logo).resizable().interpolation(.high).scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
        } else {
            IconGlyph(icon: .brand, size: size)
        }
    }
}
