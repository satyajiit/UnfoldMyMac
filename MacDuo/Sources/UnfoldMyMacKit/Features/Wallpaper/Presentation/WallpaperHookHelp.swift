import SwiftUI

struct WallpaperHookHelp: View {
    @Environment(\.appInfo) private var appInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.workspace) private var workspace
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeading(title: "When Claude is working", subtitle: "Let your wallpaper follow the session, moment by moment.")
            Text("Token counts come from local Claude Code logs. For Working, Needs you and All yours states, add the supplied hooks to your Claude Code settings, then start a new session.")
            Text("Copy the configuration and merge its hooks into ~/.claude/settings.json. Keep any hooks you already use. The connector stores only session IDs, event names and timestamps on this Mac.")
                .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
            Text("Without hooks, the scene shows recent log activity. Hook state expires after five minutes without an event; local token totals are not account billing or quota.")
                .font(UnfoldMyMacType.callout).modifier(SecondaryTextStyle())
            HStack {
                Button("Copy hook configuration") { workspace.copyToPasteboard(WallpaperHookConfiguration.claudeHooks(executable: appInfo.executablePath)) }.modifier(UnfoldMyMacButtonStyle(prominent: true))
                Spacer()
                Button("Done") { dismiss() }.modifier(UnfoldMyMacButtonStyle())
            }
        }.padding(28).frame(width: 540).font(UnfoldMyMacType.body)
    }
}
