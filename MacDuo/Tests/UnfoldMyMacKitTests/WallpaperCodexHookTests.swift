import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test func codexHookInstallerPreservesOtherHooksAndBacksUpBeforeChanging() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("hooks.json")
    let original = Data(#"{"custom":"keep","hooks":{"Stop":[{"matcher":".*","hooks":[{"type":"command","command":"echo existing"}]}],"CustomEvent":[{"hooks":[{"command":"custom"}]}]}}"#.utf8)
    try original.write(to: url)
    try CodexHookSetup.install(at: url, executable: "/Applications/It's Mine.app/Contents/MacOS/App")
    #expect(CodexHookSetup.isInstalled(at: url, executable: "/Applications/It's Mine.app/Contents/MacOS/App"))
    #expect(!CodexHookSetup.isInstalled(at: url, executable: "/A different app"))
    let updated = try Data(contentsOf: url)
    let root = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
    #expect(root["custom"] as? String == "keep")
    let hooks = try #require(root["hooks"] as? [String: Any])
    #expect(hooks["CustomEvent"] != nil)
    let stops = try #require(hooks["Stop"] as? [[String: Any]])
    #expect(stops.count == 2)
    #expect(stops[0]["matcher"] as? String == ".*")
    let text = String(decoding: updated, as: UTF8.self)
    #expect(text.contains("echo existing"))
    let handlers = try #require(stops[1]["hooks"] as? [[String: Any]])
    #expect(handlers[0]["command"] as? String == "'/Applications/It'\\''s Mine.app/Contents/MacOS/App' --wallpaper-codex-hook")
    #expect(handlers[0]["async"] as? Bool == true)
    #expect(handlers[0]["timeout"] as? Int == 2)
    try CodexHookSetup.install(at: url, executable: "/Applications/It's Mine.app/Contents/MacOS/App")
    #expect(try Data(contentsOf: url) == updated)
    let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("hooks.before") }
    #expect(backups.count == 1)
    #expect(try Data(contentsOf: #require(backups.first)) == original)
    let broken = Data("not json".utf8)
    try broken.write(to: url)
    #expect(!CodexHookSetup.isInstalled(at: url, executable: "/Applications/It's Mine.app/Contents/MacOS/App"))
    #expect(throws: (any Error).self) { try CodexHookSetup.install(at: url, executable: "/App") }
    #expect(try Data(contentsOf: url) == broken)
}

@Test func codexHookEndpointStoresOnlyMetadataAndProviderFollowsIt() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let now = Date()
    let input = Data(#"{"session_id":"s","hook_event_name":"PostToolUse","turn_id":"t","tool_use_id":"x","prompt":"PRIVATE PROMPT","tool_response":"PRIVATE OUTPUT","tool_input":{"command":"PRIVATE COMMAND"}}"#.utf8)
    try WallpaperCodexHook.record(input, directory: folder, at: now)
    try WallpaperCodexHook.record(input, directory: folder, at: now)
    let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
    #expect(files.count == 1)
    let stored = try Data(contentsOf: #require(files.first))
    #expect(!String(decoding: stored, as: UTF8.self).contains("PRIVATE"))
    let provider = CodexActivityProvider(directory: folder)
    let working = try await provider.sample(at: now)
    #expect(working.numbers["activity.tools"] == 1)
    #expect(working.numbers["activity.working"] == 1)
    let stop = Data(#"{"session_id":"s","hook_event_name":"Stop","turn_id":"t"}"#.utf8)
    try WallpaperCodexHook.record(stop, directory: folder, at: now.addingTimeInterval(1))
    let complete = try await provider.sample(at: now.addingTimeInterval(1))
    #expect(complete.numbers["activity.turns"] == 1)
    #expect(complete.text["activity.headline"] == "ORDER UP.\nPATCH SERVED.")
    #expect(try await provider.sample(at: now.addingTimeInterval(302)).numbers["activity.working"] == 0)
}

@Test func codexHookConcurrentWritersDoNotLoseCounters() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let date = Date()
    try await withThrowingTaskGroup(of: Void.self) { group in
        for index in 0..<24 {
            group.addTask {
                let data = try JSONSerialization.data(withJSONObject: ["session_id": "shared", "hook_event_name": "PostToolUse", "turn_id": "t", "tool_use_id": "tool-\(index)"])
                try WallpaperCodexHook.record(data, directory: folder, at: date)
            }
        }
        try await group.waitForAll()
    }
    #expect(try await CodexActivityProvider(directory: folder).sample(at: date).numbers["activity.tools"] == 24)
}
