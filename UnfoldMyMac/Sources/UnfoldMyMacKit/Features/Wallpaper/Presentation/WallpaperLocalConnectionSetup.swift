import SwiftUI
import UnfoldMyMacCore

/// Toggle, file and URL connections, described entirely by their connector.
struct WallpaperLocalConnectionSetup: View {
    let connector: WallpaperConnectorDescriptor
    @Binding var connection: WallpaperConnectionSettings
    @Environment(\.filePicker) private var filePicker
    @Environment(\.workspace) private var workspace
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(connector.description).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            switch connector.form {
            case .file:
                if let path = connection.path {
                    Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "doc.text")
                    Toggle(connector.toggleTitle, isOn: $connection.enabled).toggleStyle(.switch)
                }
                HStack {
                    Button("Choose data file…") {
                        filePicker.pick(WallpaperFileRequests.toolFile) { url in if let url { connection = .init(enabled: true, path: url.path) } }
                    }.modifier(UnfoldMyMacButtonStyle())
                    Button("Copy example") { workspace.copyToPasteboard(WallpaperHookConfiguration.toolExample()) }.modifier(UnfoldMyMacButtonStyle())
                    if connection.path != nil { Button("Disconnect") { connection = .init() }.buttonStyle(.plain) }
                }
            case .url:
                TextField("https://example.com/wallpaper.json", text: Binding(get: { connection.path ?? "" }, set: { connection.path = $0.isEmpty ? nil : $0 }))
                    .textFieldStyle(.roundedBorder)
                Toggle(connector.toggleTitle, isOn: $connection.enabled).toggleStyle(.switch)
            case .toggle, .githubProfile, .codexHooks, .claudeCode, .microphone, .garden, .workshop, .desktopFolder, .weather, .restTimer:
                Toggle(connector.toggleTitle, isOn: $connection.enabled).toggleStyle(.switch)
            }
        }.font(UnfoldMyMacType.callout)
    }
}
