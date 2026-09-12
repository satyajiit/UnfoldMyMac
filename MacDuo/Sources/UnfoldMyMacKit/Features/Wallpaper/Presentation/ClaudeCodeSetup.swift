import SwiftUI
import UnfoldMyMacCore

struct ClaudeCodeSetup: View {
    let connector: WallpaperConnectorDescriptor
    @Binding var connection: WallpaperConnectionSettings
    @State private var showHooks = false
    @Environment(\.filePicker) private var filePicker
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(connector.description).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            Toggle(connector.toggleTitle, isOn: $connection.enabled).toggleStyle(.switch)
            Text(connection.path ?? WallpaperPaths.defaultClaudeRoot.path).font(UnfoldMyMacType.caption).textSelection(.enabled)
                .modifier(SecondaryTextStyle()).lineLimit(2)
            HStack {
                Button("Choose log folder…") {
                    filePicker.pick(WallpaperFileRequests.claudeFolder(current: connection.path)) { url in
                        guard let url else { return }
                        connection.path = url.path; connection.enabled = true
                    }
                }.modifier(UnfoldMyMacButtonStyle())
                Button("Live work states…") { showHooks = true }.modifier(UnfoldMyMacButtonStyle())
            }
        }.font(UnfoldMyMacType.callout).sheet(isPresented: $showHooks) { WallpaperHookHelp() }
    }
}
