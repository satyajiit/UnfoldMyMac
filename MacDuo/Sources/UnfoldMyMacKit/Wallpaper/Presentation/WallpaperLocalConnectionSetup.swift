import SwiftUI
import UnfoldMyMacCore

struct WallpaperLocalConnectionSetup: View {
    let kind: WallpaperSetupRequirement.Kind
    @Binding var connection: WallpaperConnectionSettings
    @State private var showClaudeHooks = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if kind == .codexHistory {
                Text("Read retained local Codex session and token metadata. Sign in through Codex itself. Prompts and messages are never queried; totals describe local history, not account billing.")
                    .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                Toggle("Connect local Codex usage", isOn: $connection.enabled).toggleStyle(.switch)
            } else if kind == .claudeCode {
                Text("Read local Claude Code usage and session activity. Sign in in Claude Code first; no account password or key is stored here.")
                    .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                Toggle("Connect Claude Code", isOn: $connection.enabled).toggleStyle(.switch)
                Text(connection.path ?? WallpaperPaths.defaultClaudeRoot.path).font(UnfoldMyMacType.caption).textSelection(.enabled)
                    .modifier(SecondaryTextStyle()).lineLimit(2)
                HStack {
                    Button("Choose log folder…") {
                        WallpaperFileActions.chooseClaudeFolder(current: connection.path) { url in
                            connection.path = url.path; connection.enabled = true
                        }
                    }.modifier(UnfoldMyMacButtonStyle())
                    Button("Live work states…") { showClaudeHooks = true }.modifier(UnfoldMyMacButtonStyle())
                }
            } else if kind == .toolFile {
                Text("Add an updating JSON file from your script or API adapter. This connection belongs to this template.")
                    .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                if let path = connection.path {
                    Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "doc.text")
                    Toggle("Enable this feed", isOn: $connection.enabled).toggleStyle(.switch)
                }
                HStack {
                    Button("Choose data file…") {
                        WallpaperFileActions.chooseToolFile { url in connection = .init(enabled: true, path: url.path) }
                    }.modifier(UnfoldMyMacButtonStyle())
                    Button("Copy example") { WallpaperFileActions.copyToolExample() }.modifier(UnfoldMyMacButtonStyle())
                    if connection.path != nil { Button("Disconnect") { connection = .init() }.buttonStyle(.plain) }
                }
            }
        }.font(UnfoldMyMacType.callout).sheet(isPresented: $showClaudeHooks) { WallpaperHookHelp() }
    }
}
