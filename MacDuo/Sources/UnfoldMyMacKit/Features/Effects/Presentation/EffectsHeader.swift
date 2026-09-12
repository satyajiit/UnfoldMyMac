import SwiftUI
import UnfoldMyMacCore

struct EffectsHeader: View {
    @Bindable var model: EffectsModel
    let showSettings: () -> Void
    @Palette private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 24) {
                PageHeading(title: "Effects", subtitle: "Designs that move with your MacBook lid.")
                HStack(spacing: 10) {
                    Text(model.enabled ? "On" : "Off")
                        .font(UnfoldMyMacType.callout).foregroundStyle(palette.secondary)
                    NativeSwitch(isOn: Binding(get: { model.enabled }, set: { model.setEnabled($0) }), label: "Enable lid effects", identifier: "effect.enable")
                        .fixedSize()
                }
                .fixedSize()
            }
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: model.activeEffect.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 36, height: 36)
                        .background(palette.card, in: .rect(cornerRadius: 10))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(model.isPreviewing ? "Previewing" : "Selected"): \(model.activeEffect.title)")
                            .font(UnfoldMyMacType.callout).lineLimit(1)
                        Text(model.sensorAvailable ? "\(model.status) · Lid \(model.angleLabel)" : "\(model.status) · Lid sensor unavailable")
                            .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary).lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button(action: showSettings) {
                    Label("Effect settings", icon: .settings)
                }
                .modifier(UnfoldMyMacButtonStyle()).fixedSize()
                .accessibilityIdentifier("effects.settings")
            }
        }
    }
}
