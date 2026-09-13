import SwiftUI
import UnfoldMyMacCore

struct EffectInspector: View {
    private enum Pane: String { case customize = "Customize", about = "About", artwork = "Artwork" }
    @Bindable var model: EffectsModel
    var preview: (EffectID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Palette private var palette
    @State private var pane: Pane = .customize
    @State private var title = ""
    @State private var author = ""
    @State private var confirmingRemoval = false
    @State private var creditsSaved = false
    private var effect: EffectDescriptor { model.selectedEffect }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                EffectCover(url: effect.coverURL).frame(width: 92, height: 64).clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 5) {
                    Text(effect.title).font(UnfoldMyMacType.title2)
                    Text("Lid Effects · \(effect.category.title)").font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.modifier(UnfoldMyMacButtonStyle()).keyboardShortcut(.cancelAction)
            }.padding(24)
            Picker("Design settings", selection: $pane) {
                Text(Pane.customize.rawValue).tag(Pane.customize)
                Text(Pane.about.rawValue).tag(Pane.about)
                if effect.isImported { Text(Pane.artwork.rawValue).tag(Pane.artwork) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 24).padding(.bottom, 20)
                .accessibilityIdentifier("inspector.category")
            Divider()
            Group {
                switch pane {
                case .customize: EffectInspectorControls(model: model)
                case .about: EffectInspectorAbout(effect: effect)
                case .artwork: artwork
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text("Changes save as you adjust.").font(UnfoldMyMacType.caption).foregroundStyle(palette.secondary)
                Spacer()
                Button { preview(effect.id); dismiss() } label: { Label("Preview on desktop", icon: .play) }
                    .modifier(UnfoldMyMacButtonStyle(prominent: true)).accessibilityIdentifier("inspector.preview")
            }.padding(20)
        }
        .font(UnfoldMyMacType.body).foregroundStyle(palette.ink).background(palette.canvas)
        .frame(width: 640, height: 620)
        .onAppear { title = effect.title; author = effect.author }
        .onChange(of: title) { _, _ in creditsSaved = false }
        .onChange(of: author) { _, _ in creditsSaved = false }
        .alert("Remove \(effect.title) from \(AppIdentity.name)?", isPresented: $confirmingRemoval) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { if model.removeArtwork(effect.id) { dismiss() } }
        } message: { Text("This removes the app’s copy and saved reveal settings. Your original image is kept.") }
    }
    private var artwork: some View {
        Form {
            Section("Image details") {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
                Button(creditsSaved ? "Saved" : "Save details") {
                    model.updateArtworkCredits(title: title, author: author)
                    creditsSaved = model.libraryMessage == nil
                }
                if let message = model.libraryMessage { Text(message).foregroundStyle(palette.secondary) }
            }
            Section {
                Button(role: .destructive) { confirmingRemoval = true } label: { Label("Remove image", icon: .trash) }
            } footer: { Text("The app keeps its own copy. Removing it leaves your original file untouched.") }
        }.formStyle(.grouped)
    }
}
