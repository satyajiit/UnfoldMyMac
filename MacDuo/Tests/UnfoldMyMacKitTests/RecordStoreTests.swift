import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private struct Counter: Codable, Equatable { var value: Int }

// W8: digest names, a private folder, atomic writes and locked read-modify-write cycles.
@Test func recordStoreUsesDigestNamesPrivateFoldersAndSerialisedUpdates() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = RecordStore(directory: folder)
    #expect(store.url(for: "../escape").lastPathComponent == RecordStore.digest("../escape") + ".json")
    #expect(RecordStore.digest("a") != RecordStore.digest("b") && RecordStore.digest("a").count == 64)
    #expect(try store.read(Counter.self, for: "k") == nil)
    try store.write(Counter(value: 1), for: "k")
    let permissions = try FileManager.default.attributesOfItem(atPath: folder.path)[.posixPermissions] as? Int
    #expect(permissions == 0o700)
    #expect(try store.read(Counter.self, for: "k") == Counter(value: 1))
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<40 {
            group.addTask { try store.update(Counter.self, for: "k") { Counter(value: ($0?.value ?? 0) + 1) } }
        }
        try await group.waitForAll()
    }
    #expect(try store.read(Counter.self, for: "k") == Counter(value: 41))
    try store.update(Counter.self, for: "k") { _ in nil }
    #expect(try store.read(Counter.self, for: "k") == Counter(value: 41), "Returning nil leaves the record alone")
    let plist = RecordStore(directory: folder, format: .propertyList)
    try plist.write(Counter(value: 7), for: "k")
    #expect(try plist.read(Counter.self, for: "k") == Counter(value: 7))
    #expect(plist.url(for: "k").pathExtension == "plist")
}

@Test func recordStorePrunesOnlyStaleRecords() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = RecordStore(directory: folder)
    try store.write(Counter(value: 1), for: "old")
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -100_000)], ofItemAtPath: store.url(for: "old").path)
    try store.write(Counter(value: 2), for: "fresh")
    store.prune(olderThan: 86_400)
    #expect(try store.read(Counter.self, for: "old") == nil)
    #expect(try store.read(Counter.self, for: "fresh") == Counter(value: 2))
}

// W8: the Claude hook ignores an event that arrives after a newer one for the same session.
@Test func claudeHookIgnoresOutOfOrderEvents() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let now = Date()
    let working = Data(#"{"session_id":"s","hook_event_name":"PreToolUse","tool_input":{"command":"PRIVATE"}}"#.utf8)
    let done = Data(#"{"session_id":"s","hook_event_name":"Stop"}"#.utf8)
    try WallpaperClaudeHook.record(done, directory: folder, at: now.addingTimeInterval(2))
    try WallpaperClaudeHook.record(working, directory: folder, at: now)
    let stored = try #require(try RecordStore(directory: folder).read(ClaudeActivity.self, for: "s"))
    #expect(stored.event == "Stop")
    #expect(!String(decoding: try Data(contentsOf: RecordStore(directory: folder).url(for: "s")), as: UTF8.self).contains("PRIVATE"))
    try WallpaperClaudeHook.record(working, directory: folder, at: now.addingTimeInterval(3))
    #expect(try RecordStore(directory: folder).read(ClaudeActivity.self, for: "s")?.event == "PreToolUse")
}
