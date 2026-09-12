import CryptoKit
import Foundation
import UnfoldMyMacCore

/// Invoked by Claude hooks, before NSApplication starts. Never retains prompt/tool content.
public enum WallpaperClaudeHook {
    private struct Input: Decodable { let session_id: String; let hook_event_name: String }
    public static func run() -> Int32 {
        do {
            var data = Data()
            while let chunk = try FileHandle.standardInput.read(upToCount: 65_536), !chunk.isEmpty {
                guard data.count + chunk.count <= 1_048_576 else { return 0 }
                data.append(chunk)
            }
            let input = try JSONDecoder().decode(Input.self, from: data)
            guard !input.session_id.isEmpty, input.session_id.count < 256 else { return 0 }
            let activity = ClaudeActivity(session: input.session_id, event: input.hook_event_name, timestamp: .now)
            guard activity.state(at: .now) != nil else { return 0 }
            let directory = WallpaperPaths.claudeActivity
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let name = SHA256.hash(data: Data(input.session_id.utf8)).map { String(format: "%02x", $0) }.joined()
            try JSONEncoder().encode(activity).write(to: directory.appendingPathComponent(name + ".json"), options: .atomic)
            // Old heartbeats have no history value. Keep the connector bounded.
            let old = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in old where url.pathExtension == "json" {
                if let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   Date.now.timeIntervalSince(modified) > 86_400 { try? FileManager.default.removeItem(at: url) }
            }
        } catch { /* An observational hook must never block Claude's work. */ }
        return 0
    }
}
