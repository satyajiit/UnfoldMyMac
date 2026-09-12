import Foundation
import SQLite3
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test func codexWallpaperReadsOnlyLocalUserSessionAggregates() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    var db: OpaquePointer?
    #expect(sqlite3_open(root.appendingPathComponent("state_5.sqlite").path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    let now = Int(Date.now.timeIntervalSince1970)
    let sql = """
    CREATE TABLE threads (tokens_used INTEGER, updated_at INTEGER, has_user_event INTEGER, title TEXT, source TEXT);
    INSERT INTO threads VALUES (1200, \(now), 0, 'Must never be selected', 'vscode');
    INSERT INTO threads VALUES (800, 1, 0, 'Private title', 'cli');
    INSERT INTO threads VALUES (9999, \(now), 1, 'Internal thread', '{"subagent":{"thread_spawn":{}}}');
    """
    #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    let provider = CodexWallpaperProvider(root: root)
    let first = try await provider.sample(at: .now)
    #expect(first.numbers["codex.sessions"] == 2)
    #expect(first.numbers["codex.tokens"] == 2000)
    #expect(first.numbers["codex.recent"] == 1)
    #expect(!first.text.values.contains(where: { $0.contains("Private") || $0.contains("selected") }))
    #expect(sqlite3_exec(db, "UPDATE threads SET tokens_used=1400 WHERE tokens_used=1200", nil, nil, nil) == SQLITE_OK)
    #expect(try await provider.sample(at: .now).numbers["codex.tokens"] == 2200)
}

@Test @MainActor func rotatingWallpaperLinesAreDeterministicAndHonorReducedMotion() throws {
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let templates = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates
    for template in templates where template.id == "codex-foundry" || template.id == "grok-horizon" {
        let headline = try #require(template.layers.first { $0.phrases != nil })
        let phrases = try #require(headline.phrases)
        let period = try #require(headline.cycleSeconds)
        #expect(headline.value(in: .init(), at: Date(timeIntervalSince1970: 0)) == phrases[0])
        #expect(headline.value(in: .init(), at: Date(timeIntervalSince1970: period)) == phrases[1])
        #expect(headline.value(in: .init(), at: Date(timeIntervalSince1970: period), cycles: false) == phrases[0])
        #expect(!template.dataNamespaces.contains("mac"))
        var invalid = template
        invalid.layers[0].cycleSeconds = 0
        #expect(throws: WallpaperError.invalidTemplate) { try invalid.validated() }
    }
}

@Test func wallpaperMetricsMeasurePresentationGapsRatherThanGPUCompletions() {
    let metrics = FrameMetrics()
    for _ in 0..<100 { metrics.completed(gpuSeconds: 0.002, succeeded: true) }
    #expect(metrics.sample(width: 1920, height: 1200).fps == 0)
    metrics.presented(at: 1); metrics.presented(at: 1 + 1.0/60); metrics.presented(at: 1.05)
    let stats = metrics.sample(width: 1920, height: 1200)
    #expect(abs(stats.fps - 40) < 0.01)
    #expect(abs(stats.p95FrameMilliseconds - 1000.0/30) < 0.01)
    metrics.reset(); metrics.presented(at: 100)
    #expect(metrics.sample(width: 100, height: 100).fps == 0)
}
