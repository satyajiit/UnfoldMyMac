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
