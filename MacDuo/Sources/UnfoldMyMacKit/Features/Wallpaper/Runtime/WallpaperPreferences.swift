import Foundation
import UnfoldMyMacCore

struct WallpaperPreferences: Codable, Equatable, Sendable {
    var enabled = false
    var templateID = "pulse"
    var claudeConnected = false
    var codexConnected: Bool? = true
    var claudeRoot = WallpaperPaths.defaultClaudeRoot.path
    var toolPath: String?
    var customBackground = false
    var maximumFPS = 60
    static let key = PreferenceKey<WallpaperPreferences>("unfoldmymac.wallpaper.v1", default: { WallpaperPreferences() },
        sanitize: { $0.maximumFPS = $0.maximumFPS == 30 ? 30 : 60 })
    init() {}
    private enum CodingKeys: String, CodingKey { case enabled, templateID, claudeConnected, codexConnected, claudeRoot, toolPath, customBackground, maximumFPS }
    /// A payload from a release with fewer fields keeps every preference it does carry.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        templateID = try values.decodeIfPresent(String.self, forKey: .templateID) ?? "pulse"
        claudeConnected = try values.decodeIfPresent(Bool.self, forKey: .claudeConnected) ?? false
        codexConnected = try values.decodeIfPresent(Bool.self, forKey: .codexConnected)
        claudeRoot = try values.decodeIfPresent(String.self, forKey: .claudeRoot) ?? WallpaperPaths.defaultClaudeRoot.path
        toolPath = try values.decodeIfPresent(String.self, forKey: .toolPath)
        customBackground = try values.decodeIfPresent(Bool.self, forKey: .customBackground) ?? false
        maximumFPS = try values.decodeIfPresent(Int.self, forKey: .maximumFPS) ?? 60
    }
}
