import AppKit
import Observation
import QuartzCore
import UniformTypeIdentifiers
import UnfoldMyMacCore

enum AppRoute: String, CaseIterable, Identifiable, Sendable {
    case effects, wallpaper, scenes, settings
    static let features: [AppRoute] = [.effects, .wallpaper, .scenes]
    var id: String { rawValue }
    var title: String {
        switch self {
        case .effects: "Lid Effects"
        case .wallpaper: "Dynamic Wallpapers"
        case .scenes: "Creative Scenes"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .effects: UnfoldMyMacIcon.effects.rawValue
        case .wallpaper: UnfoldMyMacIcon.wallpaper.rawValue
        case .scenes: "sparkles.rectangle.stack"
        case .settings: UnfoldMyMacIcon.appSettings.rawValue
        }
    }
}
