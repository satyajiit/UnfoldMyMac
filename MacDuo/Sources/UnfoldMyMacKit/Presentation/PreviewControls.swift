import SwiftUI
import UnfoldMyMacCore

struct PreviewControls: View {
    @Bindable var model: UnfoldMyMacModel
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let p = UnfoldMyMacPalette(dark: scheme == .dark)
        VStack(spacing: 16) {
            HStack {
                Label("\(model.activeEffect.title) preview", systemImage: model.activeEffect.symbol).font(UnfoldMyMacType.headline)
                Spacer()
                Button("Stop", systemImage: UnfoldMyMacIcon.stop.rawValue, action: { model.stopPreview() })
                    .keyboardShortcut(.escape, modifiers: []).modifier(UnfoldMyMacButtonStyle(prominent: true))
            }
            ParameterRow(title: "Lid travel", valueLabel: "\(Int(model.previewClosure * 100))%", value: Binding(get: { model.previewClosure }, set: { model.scrubPreview($0) }))
            Text("Effect \(Int((model.effectProgress * 100).rounded()))% · finishes at \(Int((model.settings.completionFraction * 100).rounded()))% lid travel")
                .font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
            HStack {
                Text("Open").font(UnfoldMyMacType.caption)
                Spacer()
                if !model.reduceMotion {
                    Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? UnfoldMyMacIcon.pause.rawValue : UnfoldMyMacIcon.play.rawValue) {
                        if model.isPlaying { model.pausePreview() } else { model.playPreview() }
                    }.modifier(UnfoldMyMacButtonStyle())
                }
                Spacer()
                Text("Closed").font(UnfoldMyMacType.caption)
            }.foregroundStyle(p.secondary)
        }.font(UnfoldMyMacType.body).padding(20).frame(width: 380).background(p.card).foregroundStyle(p.ink).tint(p.controlAccent)
    }
}
