import SwiftUI

struct CodexActivitySetup: View {
    @Binding var connection: WallpaperConnectionSettings
    @State private var installed = false
    @State private var receiving = false
    @State private var error: String?
    @Environment(\.appInfo) private var appInfo
    @Environment(\.workspace) private var workspace
    private var executable: String { appInfo.executablePath }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sign in to Codex as usual. This wallpaper connects to its local activity; it never asks for your password or API key.")
                .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                Label(installed ? "Hooks installed" : "1. Install the wallpaper hooks", systemImage: installed ? "checkmark.circle.fill" : "link")
                    .font(UnfoldMyMacType.headline)
                Text("Existing hooks are preserved, with a backup before changes. Installation is shared by templates that use Codex activity.")
                    .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(installed ? "Reinstall hooks" : "Install hooks", action: install)
                        .modifier(UnfoldMyMacButtonStyle(prominent: !installed)).accessibilityIdentifier("wallpaper.codex.installHooks")
                    Button("Copy configuration") {
                        if let data = try? CodexHookSetup.configuration(existing: nil, executable: executable) {
                            workspace.copyToPasteboard(String(decoding: data, as: UTF8.self))
                        }
                    }.modifier(UnfoldMyMacButtonStyle())
                }
                Divider()
                Label("2. Review in Codex", systemImage: "checkmark.shield").font(UnfoldMyMacType.headline)
                Text("Open /hooks in Codex, review and trust these hooks, then start a new turn. Only event names, identifiers and counters are saved; prompts and responses are discarded.")
                    .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
                Link("Codex hook setup guide", destination: URL(string: "https://learn.chatgpt.com/docs/hooks")!)
                Button("Check installation") {
                    installed = CodexHookSetup.isInstalled(at: CodexHookSetup.userFile, executable: executable)
                    connection.enabled = installed
                    error = installed ? nil : "The wallpaper hooks were not found for this app. Install them or merge the copied configuration into your user hooks file."
                }.modifier(UnfoldMyMacButtonStyle())
                Divider()
                Label(receiving ? "Receiving live events" : installed ? "Waiting for the first trusted event" : "Live connection not installed",
                      systemImage: receiving ? "checkmark.circle.fill" : "circle.dotted")
                    .font(UnfoldMyMacType.headline)
                Text(receiving ? "The robot is connected to your local Codex activity." : "After installation you can use the wallpaper while completing Codex's review. It shows an explicit waiting state until events arrive.")
                    .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            }.font(UnfoldMyMacType.callout)
            if let error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            if installed {
                Toggle("Enable activity for this wallpaper", isOn: $connection.enabled).toggleStyle(.switch)
            }
        }.task {
            installed = CodexHookSetup.isInstalled(at: CodexHookSetup.userFile, executable: executable)
            if !installed { connection.enabled = false }
            let provider = CodexActivityProvider()
            while !Task.isCancelled {
                if let sample = try? await provider.sample(at: .now), let last = sample.numbers["activity.lastEvent"] {
                    receiving = last > 0 && (0...300).contains(Date.now.timeIntervalSince1970 - last)
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
    private func install() {
        do {
            try CodexHookSetup.install(at: CodexHookSetup.userFile, executable: executable)
            installed = true; connection.enabled = true; error = nil
        } catch { self.error = error.localizedDescription }
    }
}
