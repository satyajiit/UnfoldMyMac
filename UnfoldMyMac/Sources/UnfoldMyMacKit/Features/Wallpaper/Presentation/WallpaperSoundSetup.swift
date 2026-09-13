import SwiftUI

struct WallpaperSoundSetup: View {
    @Binding var connection: WallpaperConnectionSettings
    let inputs: WallpaperInputService?

    private var permissionTitle: String {
        switch inputs?.permission ?? .undetermined {
        case .undetermined: "Not requested"
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        }
    }

    private var status: String {
        guard connection.enabled else { return "Sound reactions are off." }
        return inputs?.audioStatus ?? "Waiting for microphone access."
    }

    var body: some View {
        Section {
            Toggle("React to sound", isOn: $connection.enabled)
                .toggleStyle(.switch)
                .accessibilityIdentifier("wallpaper.sound.enabled")
                .onChange(of: connection.enabled) { _, enabled in
                    if enabled { inputs?.requestMicrophonePermission() }
                }
            LabeledContent("Sensitivity") {
                HStack(spacing: 12) {
                    Slider(value: Binding(get: { connection.soundSensitivity }, set: { connection.sensitivity = $0 }), in: 0.25...4)
                        .accessibilityLabel("Sound sensitivity")
                        .accessibilityIdentifier("wallpaper.sound.sensitivity")
                    Text(String(format: "%.2g×", connection.soundSensitivity))
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
                }
                .frame(width: 280)
            }
            .disabled(!connection.enabled)
        } header: {
            Text("Sound response")
        } footer: {
            Text("Nearby sounds stir the water, sway the plants, and release a little pollen.")
        }

        Section {
            LabeledContent("Microphone access", value: permissionTitle)
                .accessibilityIdentifier("wallpaper.sound.permission")
            LabeledContent("Status") {
                Text(status)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 360, minHeight: 48, alignment: .trailing)
                    .accessibilityIdentifier("wallpaper.sound.status")
            }
        } header: {
            Text("Microphone & privacy")
        } footer: {
            Text("Sound amplitude is processed on this Mac. Audio is never recorded or saved. Listening stops when sound reactions are off or the garden isn’t visible.")
        }
    }
}
