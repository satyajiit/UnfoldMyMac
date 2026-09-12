import Foundation

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
