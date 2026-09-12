import SwiftUI
import UnfoldMyMacCore

struct EffectSettingsPage: View {
    @Bindable var model: UnfoldMyMacModel
    var body: some View {
        FeaturePage(title: "Effect settings") {
            PageHeading(title: "Effect settings", subtitle: "Lid timing, menu bar and permissions for every design.")
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                lidTiming
                menuBar
                privacy
                connection
            }
        }
    }

    private var lidTiming: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 20) {
                Text("Lid timing").font(UnfoldMyMacType.headline)
                ParameterRow(title: "Activate at or below", valueLabel: "\(Int(model.settings.activation))°", value: Binding(get: { model.settings.activation }, set: { model.setActivation($0) }), range: EffectTuning.activationRange, step: 1)
                HStack {
                    Button("Use current angle", action: { model.anchorHere() })
                        .disabled(!model.sensorAvailable).modifier(UnfoldMyMacButtonStyle())
                    Text(model.angleLabel).monospacedDigit().modifier(SecondaryTextStyle())
                }
                Text("The effect begins at this angle and builds as you close the lid. Above it, your desktop stays clear.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                Divider()
                ParameterRow(title: "Finish effect by", valueLabel: "\(Int((model.settings.completionFraction * 100).rounded()))% of lid travel", value: Binding(get: { model.settings.completionFraction }, set: { model.setCompletionFraction($0) }), range: EffectTuning.completionRange)
                Text("Full effect at about \(Int(model.completionAngle.rounded()))°. The remaining \(Int(((1 - model.settings.completionFraction) * 100).rounded()))% holds the final effect. Lower this setting to finish while the screen is easier to see.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var menuBar: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Menu bar").font(UnfoldMyMacType.headline)
                Toggle("Show lid angle in the menu bar", isOn: Binding(get: { model.settings.showAngle }, set: { model.setShowAngle($0) }))
                Text("Effects start off when you launch the app. Turn them on from the Effects page or the menu bar.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacy: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Screen Recording", icon: .privacy).font(UnfoldMyMacType.headline)
                Text("Frost needs permission to blur your desktop. It processes the built-in display in memory without saving frames or recording audio. Other designs work without screen capture.")
                    .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                Button("Screen Recording Settings…", action: { model.openScreenRecordingSettings() })
                    .modifier(UnfoldMyMacButtonStyle())
            }
        }
    }

    private var connection: some View {
        ContentCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    LabeledContent("Lid sensor", value: model.angleLabel)
                    Text(model.diagnostic).font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
                    LabeledContent("Display", value: model.displayName)
                    LabeledContent("Selected design", value: model.selectedEffect.title)
                    LabeledContent("Status", value: model.status)
                    if model.needsCapture {
                        LabeledContent("Captured frames", value: "\(model.captureFrames)")
                        LabeledContent("Last GPU frame", value: String(format: "%.2f ms", model.gpuMilliseconds))
                    }
                }.padding(.top, 16)
            } label: {
                Text("Connection & diagnostics").font(UnfoldMyMacType.headline)
            }
        }
    }
}
