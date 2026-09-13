import UnfoldMyMacCore

/// The menu-bar menu as a value, so its contents can be tested without AppKit.
struct QuickMenu: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case toggleEffect, selectEffect(EffectID), stopPreview, showWallpaper, stopWallpaper, openApp, showSettings,
             checkForUpdates, installUpdate, starRepository, quit
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
    var update: QuickMenuUpdate = .unavailable
}

/// The menu bar is the surface a user sees when the window is closed, so it says what is waiting
/// rather than offering a check they would have to think to run.
enum QuickMenuUpdate: Equatable, Sendable {
    /// Updating is off for this copy; the row is left out rather than shown disabled.
    case unavailable
    case idle
    case available(String)
    case ready(String)
}
