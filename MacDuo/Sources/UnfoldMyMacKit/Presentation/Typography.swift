import CoreText
import SwiftUI

/// App typography; SF Symbols and system-owned window/menu chrome remain native.
enum UnfoldMyMacType {
    static let body = Font.custom("SpaceGrotesk-Regular", size: 13, relativeTo: .body)
    static let callout = Font.custom("SpaceGrotesk-Regular", size: 13, relativeTo: .callout)
    static let caption = Font.custom("SpaceGrotesk-Regular", size: 12, relativeTo: .caption)
    static let headline = Font.custom("SpaceGrotesk-Medium", size: 14, relativeTo: .headline)
    static let title = Font.custom("SpaceGrotesk-Bold", size: 28, relativeTo: .title)
    static let title2 = Font.custom("SpaceGrotesk-Medium", size: 20, relativeTo: .title2)
    static let title3 = Font.custom("SpaceGrotesk-Medium", size: 16, relativeTo: .title3)

    static func register() {
        for weight in ["Regular", "Medium", "Bold"] {
            if let url = Bundle.module.url(forResource: "SpaceGrotesk-\(weight)", withExtension: "ttf", subdirectory: "Resources/Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
