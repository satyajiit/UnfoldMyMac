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
            try record(data, directory: WallpaperPaths.claudeActivity, at: .now)
        } catch { /* An observational hook must never block Claude's work. */ }
        return 0
    }
    /// Asynchronous hooks can land out of order; an older event never overwrites a newer state.
    static func record(_ data: Data, directory: URL, at date: Date) throws {
        let input = try JSONDecoder().decode(Input.self, from: data)
        guard !input.session_id.isEmpty, input.session_id.count < 256 else { return }
        let activity = ClaudeActivity(session: input.session_id, event: input.hook_event_name, timestamp: date)
        guard activity.state(at: date) != nil else { return }
        let store = RecordStore(directory: directory)
        try store.update(ClaudeActivity.self, for: input.session_id) { existing in
            if let existing, existing.timestamp > activity.timestamp { return nil }
            return activity
        }
        store.prune(olderThan: 86_400, now: date)
    }
}
