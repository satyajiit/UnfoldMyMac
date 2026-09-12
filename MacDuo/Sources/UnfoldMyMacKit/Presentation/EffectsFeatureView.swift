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

struct EffectsHeader: View {
    @Bindable var model: UnfoldMyMacModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 24) {
                PageHeading(title: "Effects", subtitle: "Designs that move with your MacBook lid.")
                HStack(spacing: 10) {
                    Text(model.enabled ? "On" : "Off")
                        .font(UnfoldMyMacType.callout).foregroundStyle(p.secondary)
                    EffectEnableSwitch(isOn: Binding(get: { model.enabled }, set: { model.setEnabled($0) }), label: "Enable lid effects")
                        .fixedSize()
                }
                .fixedSize()
            }
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: model.activeEffect.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(p.accent)
                        .frame(width: 36, height: 36)
                        .background(p.card, in: .rect(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(model.isPreviewing ? "Previewing" : "Selected"): \(model.activeEffect.title)")
                            .font(UnfoldMyMacType.callout).lineLimit(1)
                        Text(model.sensorAvailable ? "\(model.status) · Lid \(model.angleLabel)" : "\(model.status) · Lid sensor unavailable")
                            .font(UnfoldMyMacType.caption).foregroundStyle(p.secondary).lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button(action: model.showEffectSettings) {
                    Label("Effect settings", icon: .settings)
                }
                .modifier(UnfoldMyMacButtonStyle()).fixedSize()
                .accessibilityIdentifier("effects.settings")
            }
        }
    }
}
