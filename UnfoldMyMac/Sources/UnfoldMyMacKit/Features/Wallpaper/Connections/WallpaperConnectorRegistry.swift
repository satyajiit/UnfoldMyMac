import Foundation
import UnfoldMyMacCore

/// Every connector the app knows, keyed by the id templates use in `setup`. Readiness, provider assembly and
/// the setup sheet all read from here; nothing else switches on connector kinds.
struct WallpaperConnectorRegistry: Sendable {
    let connectors: [WallpaperConnectorDescriptor]

    func connector(_ id: String) -> WallpaperConnectorDescriptor? { connectors.first { $0.id == id } }

    static let standard = WallpaperConnectorRegistry(connectors: [
        .init(id: "garden", title: "Garden atmosphere", namespaces: [], form: .garden, makeProvider: { _ in nil }),
        .init(id: "microphone", title: "React to sound", namespaces: [], form: .microphone, makeProvider: { _ in nil }),
        .init(id: "mac-metrics", title: "Mac metrics", namespaces: ["mac"], implicit: true, makeProvider: { _ in MacWallpaperProvider() }),
        .init(id: "session", title: "Wallpaper session", namespaces: ["scene"], implicit: true, makeProvider: { _ in WallpaperSessionProvider() }),
        .init(id: "aurora", title: "NOAA aurora forecast", namespaces: ["aurora"], implicit: true, makeProvider: { _ in AuroraWallpaperProvider() }),
        .init(id: "github-profile", title: "GitHub profile", namespaces: ["github"], form: .githubProfile,
              validate: { $0.enabled && $0.username.flatMap { try? GitHubProfileClient.username($0) } != nil },
              makeProvider: { settings in settings.username.map { GitHubWallpaperProvider(username: $0) } }),
        .init(id: "codex-activity", title: "Codex live activity", namespaces: ["activity"], form: .codexHooks,
              makeProvider: { _ in CodexActivityProvider() }),
        .init(id: "codex-history", title: "Codex usage", namespaces: ["codex"], form: .toggle,
              description: "Read retained local Codex session and token metadata. Sign in through Codex itself. Prompts and messages are never queried; totals describe local history, not account billing.",
              toggleTitle: "Connect local Codex usage", makeProvider: { _ in CodexWallpaperProvider() }),
        .init(id: "claude-code", title: "Claude Code", namespaces: ["claude"], form: .claudeCode,
              description: "Read local Claude Code usage and session activity. Sign in in Claude Code first; no account password or key is stored here.",
              toggleTitle: "Connect Claude Code",
              makeProvider: { settings in ClaudeWallpaperProvider(root: URL(fileURLWithPath: settings.path ?? WallpaperPaths.defaultClaudeRoot.path)) }),
        .init(id: "tool-file", title: "Your tool feed", namespaces: ["tool"], form: .file,
              description: "Add an updating JSON file from your script or API adapter. This connection belongs to this template.",
              toggleTitle: "Enable this feed", validate: { $0.enabled && $0.path?.isEmpty == false },
              makeProvider: { settings in settings.path.map { WallpaperJSONProvider(url: URL(fileURLWithPath: $0)) } }),
        .init(id: "http", title: "HTTPS snapshot", namespaces: ["http"], form: .url,
              description: "Poll an HTTPS endpoint that returns a wallpaper snapshot. Credentials belong in your adapter, never in a template.",
              toggleTitle: "Enable this endpoint", validate: { $0.enabled && Self.endpoint($0) != nil },
              makeProvider: { settings in Self.endpoint(settings).flatMap { try? WallpaperHTTPProvider(id: "http", request: URLRequest(url: $0)) } }),
    ])

    private static func endpoint(_ settings: WallpaperConnectionSettings) -> URL? {
        guard let path = settings.path, let url = URL(string: path), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
