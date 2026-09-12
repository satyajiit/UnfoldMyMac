import AppKit
import SQLite3
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func activityFileCacheDecodesAFileOnlyWhenItsDateChanges() throws {
    let folder = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    let now = Date(), url = folder.appendingPathComponent("a.json")
    let encoder = JSONEncoder()
    try encoder.encode(ClaudeActivity(session: "s", event: "PreToolUse", timestamp: now)).write(to: url)
    let stamped = Date(timeIntervalSinceNow: -10)
    try FileManager.default.setAttributes([.modificationDate: stamped], ofItemAtPath: url.path)
    var cache = ActivityFileCache<ClaudeActivity>(maximumFileBytes: 4096, maximumFiles: 10)
    #expect(cache.records(in: folder, at: now).map(\.event) == ["PreToolUse"] && cache.decodes == 1)
    try encoder.encode(ClaudeActivity(session: "s", event: "Stop", timestamp: now)).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: stamped], ofItemAtPath: url.path)
    #expect(cache.records(in: folder, at: now).map(\.event) == ["PreToolUse"] && cache.decodes == 1, "Same date, no read")
    try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
    #expect(cache.records(in: folder, at: now).map(\.event) == ["Stop"] && cache.decodes == 2)
    try Data(repeating: 0x20, count: 5000).write(to: folder.appendingPathComponent("big.json"))
    try FileManager.default.removeItem(at: url)
    #expect(cache.records(in: folder, at: now).isEmpty && cache.decodes == 2, "Oversized files are skipped and removed files leave the cache")
}

@Test func codexProviderReusesItsConnectionAndFollowsTheNewestIndex() async throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    func index(_ name: String, tokens: Int) throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(root.appendingPathComponent(name).path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        #expect(sqlite3_exec(db, "CREATE TABLE threads (tokens_used INTEGER, updated_at INTEGER, has_user_event INTEGER, title TEXT, source TEXT); INSERT INTO threads VALUES (\(tokens), 1, 1, 't', 'cli');", nil, nil, nil) == SQLITE_OK)
    }
    try index("state_5.sqlite", tokens: 100)
    let provider = CodexWallpaperProvider(root: root)
    #expect(try await provider.sample(at: .now).numbers["codex.tokens"] == 100)
    #expect(try await provider.sample(at: .now).numbers["codex.tokens"] == 100)
    #expect(await provider.opens == 1)
    #expect(await provider.indexName == "state_5.sqlite", "One connection serves every sample (P19)")
    try index("state_12.sqlite", tokens: 250)
    #expect(try await provider.sample(at: .now).numbers["codex.tokens"] == 250)
    #expect(await provider.opens == 2)
    #expect(await provider.indexName == "state_12.sqlite")
    try FileManager.default.removeItem(at: root.appendingPathComponent("state_12.sqlite"))
    #expect(try await provider.sample(at: .now).numbers["codex.tokens"] == 100)
    #expect(await provider.opens == 3)
}

@Test func claudeReaderWritesItsCacheOncePerIntervalWhileAFileGrows() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let logs = root.appendingPathComponent("logs"), cache = root.appendingPathComponent("cache")
    try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    let url = logs.appendingPathComponent("s.jsonl")
    func row(_ id: String, tokens: Int) -> Data {
        Data("{\"type\":\"assistant\",\"sessionId\":\"session\",\"timestamp\":\"2026-09-12T10:00:00Z\",\"message\":{\"id\":\"\(id)\",\"usage\":{\"input_tokens\":\(tokens),\"output_tokens\":0}}}\n".utf8)
    }
    try row("a", tokens: 1).write(to: url)
    var reader = ClaudeLogReader(cacheDirectory: cache)
    let start = Date()
    try reader.refresh(root: logs, at: start)
    #expect(reader.ledger.tokens == 1 && reader.cacheWrites == 1)
    let handle = try FileHandle(forWritingTo: url); try handle.seekToEnd()
    for second in 1...4 {
        try handle.write(contentsOf: row("b\(second)", tokens: 1))
        try reader.refresh(root: logs, at: start.addingTimeInterval(Double(second)))
    }
    #expect(reader.ledger.tokens == 5, "Appended records join the ledger without a rebuild")
    #expect(reader.cacheWrites == 1, "Growth within the write interval is not flushed")
    try handle.write(contentsOf: row("c", tokens: 1)); try handle.close()
    try reader.refresh(root: logs, at: start.addingTimeInterval(ClaudeLogReader.cacheWriteInterval))
    #expect(reader.ledger.tokens == 6 && reader.cacheWrites == 2)
    #expect(try ClaudeLogCache(directory: cache).load(url).ledger.tokens == 6)
}

@MainActor private final class PruningDesktopImages: WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] = [.init(id: "one", size: CGSize(width: 320, height: 200)), .init(id: "two", size: CGSize(width: 200, height: 320))]
    var images = ["one": WallpaperDesktopImage(url: URL(fileURLWithPath: "/one.heic")), "two": WallpaperDesktopImage(url: URL(fileURLWithPath: "/two.heic"))]
    func current(on screen: String) -> WallpaperDesktopImage? { images[screen] }
    func set(_ image: WallpaperDesktopImage, on screen: String) throws { images[screen] = image }
}

@Test @MainActor func systemBackdropReusesJournalledStillsAndPrunesOldOnes() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let access = PruningDesktopImages(), originals = access.images
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let templates = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates
    #expect(templates.count > WallpaperSystemBackdrop.retainedRecordsPerDisplay)
    let backdrop = WallpaperSystemBackdrop(access: access, directory: root)
    for template in templates { try backdrop.apply(WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)) }
    func stills() throws -> [URL] { try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" } }
    #expect(try stills().count == 2 * WallpaperSystemBackdrop.retainedRecordsPerDisplay, "Each display keeps its newest companions only")
    #expect(backdrop.renders == 2 * templates.count)
    for screen in access.screens { #expect(FileManager.default.fileExists(atPath: access.images[screen.id]!.url.path)) }
    let restarted = WallpaperSystemBackdrop(access: access, directory: root)
    try restarted.apply(WallpaperPipeline(template: templates.last!, gpu: gpu, shaders: catalog))
    #expect(restarted.renders == 0, "A still rendered on an earlier launch is reused")
    try restarted.apply(WallpaperPipeline(template: templates[templates.count - 2], gpu: gpu, shaders: catalog))
    #expect(restarted.renders == 0)
    #expect(try stills().count == 2 * WallpaperSystemBackdrop.retainedRecordsPerDisplay)
    try restarted.restore()
    #expect(access.images == originals, "Pruning never loses the user's wallpaper")
}
