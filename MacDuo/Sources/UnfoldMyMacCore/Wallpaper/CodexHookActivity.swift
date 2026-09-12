import Foundation

public struct CodexHookActivity: Codable, Sendable {
    public enum State: String, Codable, Sendable { case idle, working, waiting, completed, interrupted }
    public var session: String
    public var event: String
    public var timestamp: Date
    public var turn: String?
    public var completedTurns = 0
    public var toolEvents = 0
    public var completedIDs: [String] = []
    public var toolIDs: [String] = []
    public var interruptedIDs: [String]?

    public init(session: String, event: String, timestamp: Date, turn: String? = nil) {
        self.session = session; self.event = event; self.timestamp = timestamp; self.turn = turn
    }
    public static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "Stop", "Interrupt", "SessionEnd"]
    public func state(at date: Date) -> State {
        guard (-5...300).contains(date.timeIntervalSince(timestamp)) else { return .idle }
        switch event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": return .working
        case "PermissionRequest": return .waiting
        case "Stop": return .completed
        case "Interrupt": return .interrupted
        default: return .idle
        }
    }
    public mutating func receive(event: String, turn: String?, tool: String?, at date: Date) {
        guard Self.events.contains(event), date >= timestamp else { return }
        // Async handlers can finish out of order. A landed turn cannot be made busy by its late tool callback.
        let lateTool = ["PreToolUse", "PostToolUse", "PermissionRequest"].contains(event)
            && turn != nil && (completedIDs.contains(turn!) || (interruptedIDs ?? []).contains(turn!))
        if ["Interrupt", "SessionEnd"].contains(event), let turn {
            interruptedIDs = Array(((interruptedIDs ?? []) + [turn]).suffix(128))
        }
        if event == "Stop", turn == nil || !completedIDs.contains(turn!) {
            completedTurns += 1
            if let turn { completedIDs.append(turn); completedIDs = Array(completedIDs.suffix(128)) }
        }
        if event == "PostToolUse", tool == nil || !toolIDs.contains(tool!) {
            toolEvents += 1
            if let tool { toolIDs.append(tool); toolIDs = Array(toolIDs.suffix(128)) }
        }
        if !lateTool { self.event = event; self.turn = turn; timestamp = date }
    }
}
