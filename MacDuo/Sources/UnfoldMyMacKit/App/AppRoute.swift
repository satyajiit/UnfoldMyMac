import AppKit
import Observation
import QuartzCore
import UniformTypeIdentifiers
import UnfoldMyMacCore

enum AppRoute: String, CaseIterable, Identifiable, Sendable {
    case effects, wallpaper, settings
    static let features: [AppRoute] = [.effects, .wallpaper]
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .effects: UnfoldMyMacIcon.effects.rawValue
        case .wallpaper: UnfoldMyMacIcon.wallpaper.rawValue
        case .settings: UnfoldMyMacIcon.appSettings.rawValue
        }
    }
}
