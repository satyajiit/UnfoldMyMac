import AppKit
import Observation
import QuartzCore
import UniformTypeIdentifiers
import UnfoldMyMacCore

public enum AppRoute: String, CaseIterable, Identifiable, Sendable {
    case effects, wallpaper, settings
    static let features: [AppRoute] = [.effects, .wallpaper]
    public var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .effects: UnfoldMyMacIcon.effects.rawValue
        case .wallpaper: UnfoldMyMacIcon.wallpaper.rawValue
        case .settings: UnfoldMyMacIcon.appSettings.rawValue
        }
    }
}
