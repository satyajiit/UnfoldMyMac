import Foundation

enum WallpaperPaths {
    static let root = AppSupportPaths.wallpaper
    static let claudeActivity = root.appendingPathComponent("ClaudeActivity", isDirectory: true)
    static let codexActivity = root.appendingPathComponent("CodexActivity", isDirectory: true)
    static let templates = root.appendingPathComponent("Templates", isDirectory: true)
    static let background = root.appendingPathComponent("Background.png")
    static let defaultClaudeRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
}
