import CryptoKit
import Darwin
import Foundation
import UnfoldMyMacCore

/// Observational hook endpoint: parses metadata only and always permits Codex to continue.
public enum WallpaperCodexHook {
    private struct Input: Decodable {
        let session_id: String
        let hook_event_name: String
        let turn_id: String?
        let tool_use_id: String?
    }
    public static func run() -> Int32 {
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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let name = SHA256.hash(data: Data(input.session_id.utf8)).map { String(format: "%02x", $0) }.joined()
        let lock = open(directory.appendingPathComponent(name + ".lock").path, O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(lock, LOCK_UN); close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        let url = directory.appendingPathComponent(name + ".json")
        var record = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(CodexHookActivity.self, from: $0) }
            ?? CodexHookActivity(session: input.session_id, event: "SessionStart", timestamp: date)
        record.receive(event: input.hook_event_name, turn: input.turn_id, tool: input.tool_use_id, at: date)
        try JSONEncoder().encode(record).write(to: url, options: .atomic)
    }
}
