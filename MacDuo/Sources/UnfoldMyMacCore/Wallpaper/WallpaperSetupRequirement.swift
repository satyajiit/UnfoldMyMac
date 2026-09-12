import Foundation

public struct WallpaperSetupRequirement: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case githubProfile = "github-profile"
        case codexActivity = "codex-activity"
        case codexHistory = "codex-history"
        case claudeCode = "claude-code"
        case toolFile = "tool-file"
    }
    public var kind: Kind
    public var required: Bool
    public var id: String { kind.rawValue }
    public init(kind: Kind, required: Bool) { self.kind = kind; self.required = required }
}
