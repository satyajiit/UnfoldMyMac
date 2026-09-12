import SwiftUI
import UnfoldMyMacCore

/// Each feature owns its destinations instead of expanding global preferences.
struct EffectsFeatureView: View {
    let model: EffectsModel
    @Bindable var shell: AppShellModel
    var body: some View {
        NavigationStack(path: $shell.effectsPath) {
            EffectsPage(model: model, showSettings: shell.showEffectSettings)
                .navigationDestination(for: EffectsDestination.self) { destination in
                    switch destination {
                    case .settings: EffectSettingsPage(model: model)
                    }
                }
        }
    }
}
