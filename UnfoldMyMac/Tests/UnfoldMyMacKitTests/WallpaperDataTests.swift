import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private func logRow(id: String, tokens: Int) -> Data {
    Data("{\"type\":\"assistant\",\"sessionId\":\"session\",\"timestamp\":\"2026-09-12T10:00:00Z\",\"message\":{\"id\":\"\(id)\",\"usage\":{\"input_tokens\":\(tokens),\"output_tokens\":2}}}\n".utf8)
}

@Test func wallpaperClaudeTailAppendTruncateRotateAndDelete() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("session.jsonl")
    try logRow(id: "a", tokens: 10).write(to: url)
    var reader = ClaudeLogReader(); let now = Date()
    try reader.refresh(root: directory, at: now)
    #expect(reader.ledger.tokens == 12)
    let row = logRow(id: "b", tokens: 20)
    let handle = try FileHandle(forWritingTo: url); try handle.seekToEnd()
    try handle.write(contentsOf: row.prefix(row.count-1))
    try reader.refresh(root: directory, at: now.addingTimeInterval(2))
    #expect(reader.ledger.tokens == 12)
    try handle.write(contentsOf: Data([10])); try handle.close()
    try reader.refresh(root: directory, at: now.addingTimeInterval(4))
    #expect(reader.ledger.tokens == 34)
    try logRow(id: "c", tokens: 5).write(to: url, options: .atomic)
    try reader.refresh(root: directory, at: now.addingTimeInterval(6))
    #expect(reader.ledger.tokens == 7)
    let truncate = try FileHandle(forWritingTo: url)
    try truncate.truncate(atOffset: 0); try truncate.close()
    try reader.refresh(root: directory, at: now.addingTimeInterval(8))
    #expect(reader.ledger.tokens == 0)
    try FileManager.default.removeItem(at: url)
    try reader.refresh(root: directory, at: now.addingTimeInterval(12))
    #expect(reader.ledger.tokens == 0)
}

@Test func wallpaperJSONConnectorValidatesFreshnessAndNamespace() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let now = Date()
    try encoder.encode(WallpaperDataSample(timestamp: now, numbers: ["tool.value": 42], text: ["tool.status": "BUILDING"])).write(to: url)
    let provider = WallpaperJSONProvider(url: url)
    #expect(try await provider.sample(at: now).numbers["tool.value"] == 42)
    await #expect(throws: (any Error).self) { try await provider.sample(at: now.addingTimeInterval(20)) }
    try encoder.encode(WallpaperDataSample(timestamp: now, numbers: ["mac.cpu": 42])).write(to: url)
    await #expect(throws: WallpaperError.invalidData) { try await provider.sample(at: now) }
}

private actor SlowWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "test"
    nonisolated let interval = 1.0
    func sample(at date: Date) async throws -> WallpaperDataSample {
        try? await Task.sleep(for: .milliseconds(80))
        return .init(timestamp: date, numbers: ["test.number": 1])
    }
}

@Test @MainActor func wallpaperDataHubDiscardsLateResultsAfterStop() async throws {
    let hub = WallpaperDataHub()
    hub.update([SlowWallpaperProvider()])
    try await Task.sleep(for: .milliseconds(10))
    hub.stop()
    // Absence, so a fixed wait is right, but it has to be comfortably longer than the provider's
    // 80ms: a late result that was going to land would have landed by now.
    try await Task.sleep(for: .milliseconds(400))
    #expect(hub.snapshot.sources.isEmpty)
    hub.update([SlowWallpaperProvider()])
    // Presence, so wait for the value rather than for a duration. A fixed 120ms here is not
    // reliably longer than 80ms of provider work plus scheduling on a shared runner, and the
    // test then fails for a reason that has nothing to do with the hub.
    try await settle { hub.snapshot.number("test.number") == 1 }
    #expect(hub.snapshot.number("test.number") == 1)
    hub.stop()
}

@Test func wallpaperMacProviderUsesRealBoundedMetrics() async throws {
    let provider = MacWallpaperProvider()
    _ = try await provider.sample(at: .now)
    try await Task.sleep(for: .milliseconds(80))
    let sample = try await provider.sample(at: .now)
    let cpu = try #require(sample.numbers["mac.cpu"])
    #expect((0...100).contains(cpu))
    #expect(try #require(sample.numbers["mac.memoryGB"]) > 0)
}

@Test func wallpaperClaudeCacheRetainsOnlyMetadataAndResumesPartialLines() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let logs = root.appendingPathComponent("logs"), cache = root.appendingPathComponent("cache")
    try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = logs.appendingPathComponent("s.jsonl")
    let row = logRow(id: "b", tokens: 20)
    try (logRow(id: "a", tokens: 10) + row.prefix(20)).write(to: url)
    var first = ClaudeLogReader(cacheDirectory: cache)
    try first.refresh(root: logs, at: .now)
    #expect(first.ledger.tokens == 12)
    #expect(first.cacheError == nil)
    let entry = try ClaudeLogCache(directory: cache).load(url)
    #expect(entry.offset == UInt64(logRow(id: "a", tokens: 10).count))
    let handle = try FileHandle(forWritingTo: url); try handle.seekToEnd()
    try handle.write(contentsOf: row.dropFirst(20)); try handle.close()
    var restored = ClaudeLogReader(cacheDirectory: cache)
    try restored.refresh(root: logs, at: .now)
    #expect(restored.ledger.tokens == 34 && !restored.indexing)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func wallpaperModelSeparatesPreviewFromApplyAndStopsCleanly() async throws {
    let suite = "wallpaper-tests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(), displays: FakeDisplay(), surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(), coverDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    model.start(); model.setBrowsing(true)
    model.setPreviewVisible(true)
    #expect(model.templates.count == bundledTemplateCount() && !model.enabled)
    #expect(model.previewFPS == 60)
    model.setPreviewVisible(false)
    #expect(model.previewFPS == 0 && model.playback.shouldSample)
    model.setPreviewVisible(true)
    model.select("claude-current")
    #expect(model.preferences.templateID == "pulse")
    model.apply()
    #expect(!model.enabled && model.setup.request?.template.id == "claude-current")
    model.setup.draft["claude-code"] = .init(enabled: true)
    model.setup.finish()
    #expect(model.enabled && model.preferences.templateID == "claude-current")
    model.select("daydream")
    #expect(model.activePipeline?.template.id == "claude-current")
    model.setBrowsing(false)
    #expect(model.previewFPS == 0 && model.playback.framesPerSecond > 0)
    model.stopWallpaper()
    #expect(!model.enabled && !UserDefaultsPreferencesStore(defaults: defaults).load(WallpaperPreferences.key).enabled)
    model.shutdown()
    #expect(model.data.snapshot.sources.isEmpty && model.activePipeline == nil && model.previewPipeline == nil)
}
