import SwiftUI

struct WallpaperGardenSetup: View {
    @Binding var connection: WallpaperConnectionSettings
    let inputs: WallpaperInputService?

    var body: some View {
        Section {
            Toggle("Pointer parallax", isOn: Binding(get: { connection.pointerParallax }, set: { connection.parallax = $0 }))
                .accessibilityIdentifier("wallpaper.garden.parallax")
        } header: {
            Text("Perspective")
        } footer: {
            Text("Move the pointer to look gently around the miniature.")
        }

        Section {
            Toggle("React to tilt and gyroscope", isOn: Binding(get: { connection.sensorMotion }, set: { connection.motionSensors = $0 }))
                .accessibilityIdentifier("wallpaper.garden.motion")
            LabeledContent("Sensor status") {
                Text(inputs?.motionStatus ?? "Motion sensors respond while the garden is playing.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 330, minHeight: 48, alignment: .trailing)
            }
        } header: {
            Text("Mac movement")
        } footer: {
            Text("Supported sensors gently shift the view and stir the water when you move your Mac. Motion follows your system’s Reduce Motion setting.")
        }
    }
}
