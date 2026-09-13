import SwiftUI

struct WallpaperOneLinerSetup: View {
    @Binding var connection: WallpaperConnectionSettings
    let soundEnabled: Bool

    var body: some View {
        Section {
            Toggle("Show motivational one-liners", isOn: Binding(get: { connection.showsOneLiners }, set: { connection.oneLiners = $0 }))
                .accessibilityIdentifier("wallpaper.garden.quotes")
            Picker("Change line every", selection: Binding(get: { connection.rotationInterval }, set: { connection.lineInterval = $0 })) {
                Text("15 seconds").tag(15.0)
                Text("45 seconds").tag(45.0)
                Text("2 minutes").tag(120.0)
            }
            .disabled(!connection.showsOneLiners)
            .accessibilityIdentifier("wallpaper.garden.interval")
        } header: {
            Text("On your desktop").font(UnfoldMyMacType.headline)
        } footer: {
            Text("A little encouragement, set in larger type. Each line fades softly into the next.")
                .font(UnfoldMyMacType.caption)
        }

        Section {
            Toggle("Blow gently to change the line", isOn: Binding(get: { connection.changesLineOnBlow }, set: { connection.blowToChange = $0 }))
                .disabled(!connection.showsOneLiners || !soundEnabled)
                .accessibilityIdentifier("wallpaper.garden.blow")
            LabeledContent("Sound reactions", value: soundEnabled ? "On" : "Off — enable in Sound")
                .foregroundStyle(.secondary)
        } header: {
            Text("A fresh thought").font(UnfoldMyMacType.headline)
        } footer: {
            Text("With React to sound enabled, blow toward the microphone for about half a second. Sustained nearby sounds can also advance a line.")
                .font(UnfoldMyMacType.caption)
        }
    }
}
