import SwiftUI

struct WallpaperRestSetup: View {
    let connector: WallpaperConnectorDescriptor
    @Binding var connection: WallpaperConnectionSettings
    @State private var restartRequested = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(connector.description).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            Stepper(value: Binding(get: { connection.restMinutes(default: connector.id == "grace-focus" ? 25 : 20) },
                                   set: { connection.sessionMinutes = $0 }), in: 1...60, step: 1) {
                Text("\(Int(connection.restMinutes(default: connector.id == "grace-focus" ? 25 : 20))) minutes")
            }.accessibilityIdentifier("wallpaper.rest.minutes")
            Button(restartRequested ? "Restart scheduled" : "Restart timer") {
                connection.sessionRestart = UUID().uuidString; restartRequested = true
            }
                .modifier(UnfoldMyMacButtonStyle()).accessibilityIdentifier("wallpaper.rest.restart")
            Text("Saved changes take effect on the desktop when you apply them.")
                .font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle())
        }
    }
}
