import Foundation

/// The text the setup sheets put on the pasteboard: a Claude Code hooks block that calls this executable, and a
/// sample of the JSON the tool-file connector reads.
enum WallpaperHookConfiguration {
    static let claudeEvents = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "StopFailure", "SessionEnd"]

    static func claudeHooks(executable: String) -> String {
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "' --wallpaper-claude-hook"
        let entry: [[String: Any]] = [["hooks": [["type": "command", "command": quoted, "timeout": 3]]]]
        let config = ["hooks": Dictionary(uniqueKeysWithValues: claudeEvents.map { ($0, entry) })]
        // Strings, integers and arrays only, so serialisation cannot fail; the fallback keeps the type honest.
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
    static func toolExample(date: Date = .now) -> String {
        """
        {"timestamp":"\(date.ISO8601Format())","numbers":{"tool.value":42},"text":{"tool.label":"BUILD STATUS","tool.status":"ALL SYSTEMS GO."},"status":"Live"}
        """
    }
}
