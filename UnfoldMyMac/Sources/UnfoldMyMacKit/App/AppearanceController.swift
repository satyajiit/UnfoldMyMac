import AppKit
import Observation
import UnfoldMyMacCore

/// Applies the appearance preference process-wide.
@MainActor final class AppearanceController {
    private let model: EffectsModel
    private var observation: Task<Void, Never>?
    init(model: EffectsModel) { self.model = model }
    func start() {
        let model = self.model
        observation = Task { for await appearance in Observations({ model.settings.appearance }) { Self.apply(appearance) } }
    }
    func stop() { observation?.cancel(); observation = nil }
    isolated deinit { stop() }

    static func apply(_ appearance: AppearancePreference) {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
