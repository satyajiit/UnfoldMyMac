import Foundation

public struct ClaudeUsageLedger: Codable, Sendable {
    public private(set) var records: [String: ClaudeUsageRecord] = [:]
    private var totalTokens = 0.0
    private var sessionActivity: [String: Date] = [:]
    public init() {}
    /// Streaming revisions and copied transcripts count a request once, preserving final usage.
    public mutating func ingest(_ record: ClaudeUsageRecord) {
        guard let old = records[record.key] else {
            records[record.key] = record; totalTokens += record.total; recordActivity(record); return
        }
        var merged = old
        merged.input = max(old.input, record.input); merged.output = max(old.output, record.output)
        merged.cacheRead = max(old.cacheRead, record.cacheRead); merged.cacheWrite = max(old.cacheWrite, record.cacheWrite)
        merged.timestamp = max(old.timestamp, record.timestamp)
        records[record.key] = merged
        totalTokens += merged.total-old.total; recordActivity(merged)
    }
    public var tokens: Double { totalTokens }
    public var sessions: Int { sessionActivity.count }
    public func activeSessions(at date: Date) -> Int {
        sessionActivity.values.filter { (0...60).contains(date.timeIntervalSince($0)) }.count
    }
    private mutating func recordActivity(_ record: ClaudeUsageRecord) {
        sessionActivity[record.session] = max(sessionActivity[record.session] ?? .distantPast, record.timestamp)
    }
    private enum CodingKeys: String, CodingKey { case records }
    public init(from decoder: any Decoder) throws {
        records = try decoder.container(keyedBy: CodingKeys.self).decode([String: ClaudeUsageRecord].self, forKey: .records)
        for record in records.values { totalTokens += record.total; recordActivity(record) }
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(records, forKey: .records)
    }
}

/// Incremental framing preserves unfinished writes and discards oversized lines in bounded memory.
