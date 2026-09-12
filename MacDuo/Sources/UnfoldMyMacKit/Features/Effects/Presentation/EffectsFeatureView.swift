import SwiftUI
import UnfoldMyMacCore

/// Each feature owns its destinations instead of expanding global preferences.
struct EffectsFeatureView: View {
    @Bindable var model: UnfoldMyMacModel
    var body: some View {
        NavigationStack(path: $model.effectsPath) {
            EffectsPage(model: model)
                .navigationDestination(for: EffectsDestination.self) { destination in
                    switch destination {
                    case .settings: EffectSettingsPage(model: model)
                    }
                }
        }
    }
}
