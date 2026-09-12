import UnfoldMyMacCore

/// The menu-bar menu as a value, so its contents can be tested without AppKit.
struct QuickMenu: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case toggleEffect, selectEffect(EffectID), stopPreview, showWallpaper, stopWallpaper, openApp, showSettings, starRepository, quit
    }
    indirect enum Item: Equatable, Sendable {
        case label(String)
        case action(String, Action, checked: Bool = false)
        case submenu(String, [Item])
        case separator
    }
    var items: [Item]
}

struct QuickMenuState {
    var status: String
    var effectEnabled: Bool
    var isPreviewing: Bool
    var selectedEffect: EffectID
    var wallpaperEnabled: Bool
    var effects: [EffectDescriptor]
}
