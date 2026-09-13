import Foundation
import UnfoldMyMacCore

/// Observational hook endpoint: parses metadata only and always permits Codex to continue.
enum WallpaperCodexHook {
    private struct Input: Decodable {
        let session_id: String
        let hook_event_name: String
        let turn_id: String?
        let tool_use_id: String?
    }
    static func run() -> Int32 {
        defer { FileHandle.standardOutput.write(Data("{}\n".utf8)) }
        do {
            var data = Data()
            while let chunk = try FileHandle.standardInput.read(upToCount: 65_536), !chunk.isEmpty {
                guard data.count + chunk.count <= 1_048_576 else { return 0 }
                data.append(chunk)
            }
            try record(data, directory: WallpaperPaths.codexActivity, at: .now)
        } catch { /* Failure to observe never blocks agent work. */ }
        return 0
    }
    static func record(_ data: Data, directory: URL, at date: Date) throws {
        guard data.count <= 1_048_576 else { return }
        let input = try JSONDecoder().decode(Input.self, from: data)
        guard !input.session_id.isEmpty, input.session_id.count <= 256,
              (input.turn_id?.count ?? 0) <= 256, (input.tool_use_id?.count ?? 0) <= 256,
              CodexHookActivity.events.contains(input.hook_event_name) else { return }
        try RecordStore(directory: directory).update(CodexHookActivity.self, for: input.session_id) { existing in
            var record = existing ?? CodexHookActivity(session: input.session_id, event: "SessionStart", timestamp: date)
            record.receive(event: input.hook_event_name, turn: input.turn_id, tool: input.tool_use_id, at: date)
            return record
        }
    }
}
