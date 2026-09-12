import Foundation

/// Intentionally decodes metadata only. Prompt, tool input and assistant content are discarded.
public struct ClaudeUsageRecord: Codable, Equatable, Sendable {
    public var key: String
    public var session: String
    public var timestamp: Date
    public var input: Double
    public var output: Double
    public var cacheRead: Double
    public var cacheWrite: Double
    public var total: Double { input + output + cacheRead + cacheWrite }

    public static func decode(_ data: Data) -> Self? {
        guard let row = try? JSONDecoder().decode(Row.self, from: data), row.type == "assistant",
              let message = row.message, let usage = message.usage,
              let session = row.sessionId, let id = message.id,
              let date = WallpaperJSONDate.parse(row.timestamp) else { return nil }
        let values = [usage.input_tokens, usage.output_tokens, usage.cache_read_input_tokens, usage.cache_creation_input_tokens].map { $0 ?? 0 }
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 1e12 }) else { return nil }
        return .init(key: id, session: session, timestamp: date,
                     input: values[0], output: values[1], cacheRead: values[2], cacheWrite: values[3])
    }
    private struct Row: Decodable {
        let type: String?
        let sessionId: String?
        let requestId: String?
        let timestamp: String?
        let message: Message?
    }
    private struct Message: Decodable { let id: String?; let usage: Usage? }
    private struct Usage: Decodable {
        let input_tokens: Double?
        let output_tokens: Double?
        let cache_read_input_tokens: Double?
        let cache_creation_input_tokens: Double?
    }
}

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
public struct WallpaperJSONLines: Sendable {
    private var pending = Data()
    private var discarding = false
    public private(set) var uncommittedByteCount = 0
    public let maximumLineBytes: Int
    public init(maximumLineBytes: Int = 4 * 1024 * 1024) { self.maximumLineBytes = maximumLineBytes }
    public mutating func append(_ chunk: Data) -> [Data] {
        var result: [Data] = []
        for part in chunk.split(separator: 10, omittingEmptySubsequences: false).enumerated() {
            if part.offset > 0 {
                if !discarding && !pending.isEmpty { result.append(pending) }
                pending.removeAll(keepingCapacity: true); discarding = false
                uncommittedByteCount = 0
            }
            if pending.count + part.element.count > maximumLineBytes { pending.removeAll(keepingCapacity: true); discarding = true }
            if !discarding { pending.append(contentsOf: part.element) }
            uncommittedByteCount += part.element.count
        }
        return result
    }
}
