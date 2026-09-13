import SwiftUI
import UnfoldMyMacCore

struct EffectInspectorControls: View {
    @Bindable var model: EffectsModel
    @Palette private var palette
    private var effect: EffectDescriptor { model.selectedEffect }
    private var groups: [String] {
        effect.parameters.map(\.groupTitle).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
    var body: some View {
        Form {
            ForEach(groups, id: \.self) { group in
                Section {
                    ForEach(effect.parameters.filter { $0.groupTitle == group }) { spec in parameterControl(spec) }
                } header: { Text(group) }
            }
            Section("Preview & behavior") {
                Label("Responds to your MacBook lid", systemImage: "laptopcomputer")
                Text(effect.hasContinuousMotion ? "Play a preview to see the movement. Pause holds the current frame; scrub to explore the lid’s range." : "Preview on your desktop, then scrub through the lid’s range to find the look you like.")
                    .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                Text("Activation angle and completion are shared by all designs. Change them in Lid & timing.")
                    .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
            }
        }.formStyle(.grouped).toggleStyle(.switch).scrollBounceBehavior(.basedOnSize)
    }
    @ViewBuilder private func parameterControl(_ spec: EffectParameterSpec) -> some View {
        let value = model.parameters[spec.key] ?? spec.default
        switch spec.kind {
        case .choice:
            Picker(spec.title, selection: Binding(get: { value.choice ?? spec.default.choice ?? "" }, set: { model.setParameter(spec.key, .choice($0)) })) {
                ForEach(spec.choices) { Text($0.title).tag($0.id) }
            }.accessibilityIdentifier("effect.\(spec.key)")
        case .toggle:
            Toggle(spec.title, isOn: Binding(get: { value.flag ?? spec.default.flag ?? false }, set: { model.setParameter(spec.key, .flag($0)) }))
                .accessibilityIdentifier("effect.\(spec.key)")
        case .slider:
            let number = spec.clamp(value).number ?? spec.minimum
            ParameterRow(title: spec.title, valueLabel: spec.format == .percent ? "\(Int((number * 100).rounded()))%" : number.formatted(.number.precision(.fractionLength(0...2))),
                value: Binding(get: { number }, set: { model.setParameter(spec.key, .number($0)) }), range: spec.minimum...spec.maximum, step: spec.step)
        }
    }
}
