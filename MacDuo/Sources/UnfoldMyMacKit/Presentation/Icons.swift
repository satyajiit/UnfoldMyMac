import SwiftUI

/// One semantic SF Symbols vocabulary for navigation, actions, effects, and state.
/// Add names here instead of scattering string literals or drawing replacement icons.
enum UnfoldMyMacIcon: String, CaseIterable {
    case brand = "circle.lefthalf.filled"
    case effects = "square.grid.2x2"
    case wallpaper = "rectangle.on.rectangle.angled"
    case connection = "point.3.connected.trianglepath.dotted"
    case motion = "waveform.path"
    case settings = "slider.horizontal.3"
    case appSettings = "gearshape"
    case frost = "snowflake"
    case veil = "square.stack.3d.up"
    case fade = "moon"
    case curtains = "theatermasks"
    case reverie = "moon.stars"
    case neonCoast = "sun.horizon"
    case image = "photo"
    case current = "water.waves"
    case peekaboo = "eyes"
    case rise = "sun.max"
    case clear = "xmark.circle.fill"
    case search = "magnifyingglass"
    case importImage = "photo.badge.plus"
    case folder = "folder"
    case trash = "trash"
    case author = "person.crop.circle"
    case laptop = "laptopcomputer"
    case display = "display"
    case selected = "checkmark.circle.fill"
    case unselected = "circle"
    case idle = "pause.circle"
    case play = "play.fill"
    case pause = "pause.fill"
    case stop = "stop.fill"
    case privacy = "lock.shield"
    case warning = "exclamationmark.circle"
    case accessibility = "accessibility"
}

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

@MainActor enum BrandAssets {
    static let logo: NSImage? = Bundle.module.url(forResource: "UnfoldMyMacLogo", withExtension: "png", subdirectory: "Resources/Brand").flatMap(NSImage.init(contentsOf:))
}

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

extension Label where Title == Text, Icon == Image {
    init(_ title: String, icon: UnfoldMyMacIcon) { self.init(title, systemImage: icon.rawValue) }
}
