import SwiftUI
import UnfoldMyMacCore

struct EffectInspector: View {
    @Bindable var model: EffectsModel
    var preview: (EffectID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Palette private var palette
    @State private var title = ""
    @State private var author = ""
    @State private var confirmingRemoval = false
    @State private var creditsSaved = false
    var body: some View {
        let effect = model.selectedEffect
        VStack(spacing: 0) {
            HStack {
                Text(effect.title).font(UnfoldMyMacType.title2)
                Spacer()
                Button("Done") { dismiss() }.modifier(UnfoldMyMacButtonStyle()).keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EffectCover(url: effect.coverURL, contentMode: .fit).frame(height: 170).clipShape(.rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(effect.subtitle).font(UnfoldMyMacType.title2)
                        Text(effect.detail).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                        Label("By \(effect.author)\(effect.credit.isEmpty ? "" : " · \(effect.credit)")", icon: .author)
                            .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                        Text(effect.tags.joined(separator: " · ")).font(UnfoldMyMacType.caption).foregroundStyle(palette.accent)
                    }
                    Divider()
                    ForEach(effect.parameters) { spec in parameterControl(spec) }
                    if effect.hasContinuousMotion {
                        Text("Play a preview to see the flow. Pause holds the frame for inspection.")
                            .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                    }
                    if effect.isImported {
                        Divider()
                        Text("Image details").font(UnfoldMyMacType.headline)
                        TextField("Title", text: $title).textFieldStyle(.roundedBorder)
                        TextField("Author", text: $author).textFieldStyle(.roundedBorder)
                        HStack {
                            Button(creditsSaved ? "Saved" : "Save details") {
                                model.updateArtworkCredits(title: title, author: author)
                                creditsSaved = model.libraryMessage == nil
                            }.modifier(UnfoldMyMacButtonStyle())
                            Spacer()
                            Button(role: .destructive) { confirmingRemoval = true } label: { Label("Remove image", icon: .trash) }
                        }
                        Text("\(AppIdentity.name) keeps its own copy. Removing this design leaves your original file untouched.")
                            .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                    }
                    if let message = model.libraryMessage { Text(message).foregroundStyle(palette.secondary).font(UnfoldMyMacType.callout) }
                }.padding(24)
            }
            Divider()
            HStack {
                Text(effect.requiresCapture ? "Uses Screen Recording" : "No Screen Recording needed")
                    .font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                Spacer()
                Button { preview(effect.id); dismiss() } label: { Label("Preview", icon: .play) }
                    .modifier(UnfoldMyMacButtonStyle(prominent: true))
                    .accessibilityIdentifier("inspector.preview")
            }.padding(20)
        }
        .font(UnfoldMyMacType.body).foregroundStyle(palette.ink).background(palette.canvas)
        .frame(width: 580, height: 620)
        .onAppear { title = effect.title; author = effect.author }
        .onChange(of: title) { _, _ in creditsSaved = false }
        .onChange(of: author) { _, _ in creditsSaved = false }
        .alert("Remove \(effect.title) from \(AppIdentity.name)?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { if model.removeArtwork(effect.id) { dismiss() } }
        } message: { Text("This removes \(AppIdentity.name)’s copy and its saved reveal settings. Your original image is kept.") }
    }
    /// Each declared parameter draws the control its kind names; the effect never needs a bespoke view.
    @ViewBuilder private func parameterControl(_ spec: EffectParameterSpec) -> some View {
        let value = model.parameters[spec.key] ?? spec.default
        switch spec.kind {
        case .choice:
            Picker(spec.title, selection: Binding(get: { value.choice ?? spec.default.choice ?? "" }, set: { model.setParameter(spec.key, .choice($0)) })) {
                ForEach(spec.choices) { Text($0.title).tag($0.id) }
            }.pickerStyle(.segmented).accessibilityIdentifier("effect.\(spec.key)")
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
