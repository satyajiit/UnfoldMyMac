import Foundation
import Testing
@testable import UnfoldMyMacCore

@Test func wallpaperPlaybackHonorsSleepPowerAndMotion() {
    var policy = WallpaperPlayback()
    #expect(policy.framesPerSecond == 0 && !policy.shouldSample)
    policy.preview = true
    #expect(policy.framesPerSecond == 60 && policy.shouldSample)
    policy.lowPower = true
    #expect(policy.framesPerSecond == 30)
    policy.reducedMotion = true
    #expect(policy.framesPerSecond == 1 && !policy.animates)
    policy.sleeping = true
    #expect(policy.framesPerSecond == 0 && !policy.shouldSample)
    policy.sleeping = false; policy.preview = false; policy.enabled = true; policy.reducedMotion = false
    policy.lowPower = false; policy.thermallyLimited = true
    #expect(policy.framesPerSecond == 30)
}

@Test func wallpaperSnapshotRejectsStaleInvalidAndCrossProviderValues() throws {
    let now = Date()
    var snapshot = WallpaperSnapshot()
    snapshot.sources["mac"] = .init(timestamp: now, numbers: ["mac.cpu": 34])
    #expect(snapshot.number("mac.cpu", at: now) == 34)
    #expect(snapshot.number("mac.cpu", at: now.addingTimeInterval(16)) == nil)
    snapshot.errors["mac"] = "Offline"
    #expect(snapshot.number("mac.cpu", at: now) == nil)
    #expect(throws: WallpaperError.invalidData) { try WallpaperDataSample(timestamp: now, numbers: ["claude.tokens": 12]).validated(namespace: "mac") }
    #expect(throws: WallpaperError.invalidData) { try WallpaperDataSample(timestamp: now, numbers: ["mac.cpu": .nan]).validated(namespace: "mac") }
}

@Test func wallpaperJSONLinesKeepsPartialWritesAndRecoversAfterOversizedLines() {
    var lines = WallpaperJSONLines(maximumLineBytes: 12)
    #expect(lines.append(Data("first\npar".utf8)) == [Data("first".utf8)])
    #expect(lines.append(Data("tial\n".utf8)) == [Data("partial".utf8)])
    #expect(lines.append(Data("1234567890123456".utf8)).isEmpty)
    #expect(lines.append(Data("78\nok\n".utf8)) == [Data("ok".utf8)])
}

private func usageRow(output: Int, session: String = "s1") -> Data {
    Data("""
    {"type":"assistant","sessionId":"\(session)","requestId":"r1","timestamp":"2026-09-12T10:00:00.123Z","message":{"id":"m1","content":[{"text":"not retained"}],"usage":{"input_tokens":100,"output_tokens":\(output),"cache_read_input_tokens":300,"cache_creation_input_tokens":200}}}
    """.utf8)
}

@Test func wallpaperClaudeCountsStreamingRevisionsAndCopiedTranscriptsOnce() throws {
    var ledger = ClaudeUsageLedger()
    let first = try #require(ClaudeUsageRecord.decode(usageRow(output: 10)))
    ledger.ingest(first)
    ledger.ingest(try #require(ClaudeUsageRecord.decode(usageRow(output: 30))))
    ledger.ingest(first)
    ledger.ingest(try #require(ClaudeUsageRecord.decode(usageRow(output: 30, session: "copied-session"))))
    #expect(ledger.tokens == 630 && ledger.records.count == 1)
    #expect(ledger.activeSessions(at: first.timestamp.addingTimeInterval(61)) == 0)
    #expect(ClaudeUsageRecord.decode(Data("{\"type\":\"user\",\"message\":{\"content\":\"secret\"}}".utf8)) == nil)
}

@Test func wallpaperClaudeHookStateExpiresAndDistinguishesWaitingFromWorking() {
    let now = Date()
    #expect(ClaudeActivity(session: "a", event: "PreToolUse", timestamp: now).state(at: now) == "WORKING.")
    #expect(ClaudeActivity(session: "a", event: "PermissionRequest", timestamp: now).state(at: now) == "NEEDS YOU.")
    #expect(ClaudeActivity(session: "a", event: "Stop", timestamp: now).state(at: now) == "ALL YOURS.")
    #expect(ClaudeActivity(session: "a", event: "PreToolUse", timestamp: now).state(at: now.addingTimeInterval(301)) == nil)
}
