import Foundation

/// The id a template's `setup` names and a connector descriptor answers to. Open, so a template may ask for a
/// connector this build does not ship: required ones reject the template, optional ones only warn.
public struct WallpaperConnectorID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
    public var isValid: Bool { rawValue.range(of: #"^[a-z0-9][a-z0-9-]{0,39}$"#, options: .regularExpression) != nil }

    public static let githubProfile = WallpaperConnectorID(rawValue: "github-profile")
    public static let codexActivity = WallpaperConnectorID(rawValue: "codex-activity")
    public static let codexHistory = WallpaperConnectorID(rawValue: "codex-history")
    public static let claudeCode = WallpaperConnectorID(rawValue: "claude-code")
    public static let toolFile = WallpaperConnectorID(rawValue: "tool-file")
    public static let http = WallpaperConnectorID(rawValue: "http")
    /// The configurable connectors the bundled templates may name.
    public static let bundled: [WallpaperConnectorID] = [.githubProfile, .codexActivity, .codexHistory, .claudeCode, .toolFile, .http]
}
