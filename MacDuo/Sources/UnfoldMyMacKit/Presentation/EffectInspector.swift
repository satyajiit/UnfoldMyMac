import SwiftUI
import UnfoldMyMacCore

struct EffectInspector: View {
    @Bindable var model: UnfoldMyMacModel
    var preview: (EffectID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var title = ""
    @State private var author = ""
    @State private var confirmingRemoval = false
    @State private var creditsSaved = false
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
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
                        Text(effect.detail).foregroundStyle(p.secondary).fixedSize(horizontal: false, vertical: true)
                        Label("By \(effect.author)\(effect.credit.isEmpty ? "" : " · \(effect.credit)")", icon: .author)
                            .font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
                        Text(effect.tags.joined(separator: " · ")).font(UnfoldMyMacType.caption).foregroundStyle(p.accent)
                    }
                    Divider()
                    if let defaultReveal = effect.defaultReveal {
                        Picker("Reveal", selection: Binding(get: { model.parameters.reveal ?? defaultReveal }, set: { model.setReveal($0) })) {
                            ForEach(ArtRevealMotion.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("effect.reveal")
                    }
                    ParameterRow(title: effect.parameterTitle, valueLabel: "\(Int(model.parameters.strength * 100))%",
                        value: Binding(get: { model.parameters.strength }, set: { model.setStrength($0) }))
                    if effect.hasContinuousMotion {
                        Text("Play a preview to see the flow. Pause holds the frame for inspection.")
                            .font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
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
                            .font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
                    }
                    if let message = model.libraryMessage { Text(message).foregroundStyle(p.secondary).font(UnfoldMyMacType.callout) }
                }.padding(24)
            }
            Divider()
            HStack {
                Text(effect.requiresCapture ? "Uses Screen Recording" : "No Screen Recording needed")
                    .font(UnfoldMyMacType.caption).foregroundStyle(p.secondary)
                Spacer()
                Button { preview(effect.id); dismiss() } label: { Label("Preview", icon: .play) }
                    .modifier(UnfoldMyMacButtonStyle(prominent: true))
                    .accessibilityIdentifier("inspector.preview")
            }.padding(20)
        }
        .font(UnfoldMyMacType.body).foregroundStyle(p.ink).background(p.canvas)
        .frame(width: 580, height: 620)
        .onAppear { title = effect.title; author = effect.author }
        .onChange(of: title) { _, _ in creditsSaved = false }
        .onChange(of: author) { _, _ in creditsSaved = false }
        .alert("Remove \(effect.title) from \(AppIdentity.name)?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { if model.removeArtwork(effect.id) { dismiss() } }
        } message: { Text("This removes \(AppIdentity.name)’s copy and its saved reveal settings. Your original image is kept.") }
    }
}
