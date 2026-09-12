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
