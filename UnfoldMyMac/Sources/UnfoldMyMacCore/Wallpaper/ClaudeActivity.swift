import Foundation

public struct ClaudeActivity: Codable, Sendable, Equatable {
    public let session: String
    public let event: String
    public let timestamp: Date
    public init(session: String, event: String, timestamp: Date) {
        self.session = session; self.event = event; self.timestamp = timestamp
    }
    public func state(at date: Date) -> String? {
        guard (0...300).contains(date.timeIntervalSince(timestamp)) else { return nil }
        switch event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": return "WORKING."
        case "PermissionRequest", "Notification": return "NEEDS YOU."
        case "Stop", "StopFailure", "SessionEnd": return "ALL YOURS."
        default: return nil
        }
    }
}
