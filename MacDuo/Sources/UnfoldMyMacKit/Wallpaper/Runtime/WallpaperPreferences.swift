import Foundation

enum WallpaperPaths {
    static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("UnfoldMyMac/Wallpaper", isDirectory: true)
    static let claudeActivity = root.appendingPathComponent("ClaudeActivity", isDirectory: true)
    static let codexActivity = root.appendingPathComponent("CodexActivity", isDirectory: true)
    static let templates = root.appendingPathComponent("Templates", isDirectory: true)
    static let background = root.appendingPathComponent("Background.png")
    static let defaultClaudeRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
}

struct WallpaperPreferences: Codable, Equatable {
    var enabled = false
    var templateID = "pulse"
    var claudeConnected = false
    var codexConnected: Bool? = true
    var claudeRoot = WallpaperPaths.defaultClaudeRoot.path
    var toolPath: String?
    var customBackground = false
    var maximumFPS = 60
    private static let key = "unfoldmymac.wallpaper.v1"
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: key), var value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        value.maximumFPS = value.maximumFPS == 30 ? 30 : 60
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
