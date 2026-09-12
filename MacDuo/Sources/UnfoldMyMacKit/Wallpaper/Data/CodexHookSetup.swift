import Foundation
import UnfoldMyMacCore

enum CodexHookSetup {
    static var userFile: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/hooks.json") }
    static func isInstalled(at url: URL, executable: String) -> Bool {
        guard let data = try? Data(contentsOf: url), data.count <= 1_048_576,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = root["hooks"] as? [String: [[String: Any]]] else { return false }
        let command = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "' --wallpaper-codex-hook"
        return CodexHookActivity.events.allSatisfy { event in
            (hooks[event] ?? []).contains { group in
                (group["hooks"] as? [[String: Any]] ?? []).contains {
                    $0["type"] as? String == "command" && $0["command"] as? String == command
                }
            }
        }
    }
    static func configuration(existing: Data?, executable: String) throws -> Data {
        var root: [String: Any] = [:]
        if let existing {
            guard existing.count <= 1_048_576, let value = try JSONSerialization.jsonObject(with: existing) as? [String: Any] else { throw WallpaperError.invalidData }
            root = value
        }
        if let hooks = root["hooks"], !(hooks is [String: Any]) { throw WallpaperError.invalidData }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "' --wallpaper-codex-hook"
        for event in CodexHookActivity.events {
            if let groups = hooks[event], !(groups is [[String: Any]]) { throw WallpaperError.invalidData }
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups = try groups.compactMap { group in
                guard let handlers = group["hooks"] as? [[String: Any]] else { throw WallpaperError.invalidData }
                var group = group
                let retained = handlers.filter { !(($0["command"] as? String)?.contains("--wallpaper-codex-hook") ?? false) }
                guard !retained.isEmpty else { return nil }
                group["hooks"] = retained; return group
            }
            groups.append(["hooks": [["type": "command", "command": command, "async": true, "timeout": 2]]])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
    static func install(at url: URL, executable: String) throws {
        let manager = FileManager.default
        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            throw WallpaperError.unavailable("Your hooks file is managed by a symbolic link. Use Copy configuration and merge it with that file.")
        }
        let existing = manager.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        let updated = try configuration(existing: existing, executable: executable)
        guard updated != existing else { return }
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let existing {
            try existing.write(to: url.deletingLastPathComponent().appendingPathComponent("hooks.before-unfold-" + UUID().uuidString + ".json"), options: .atomic)
        }
        try updated.write(to: url, options: .atomic)
    }
}
