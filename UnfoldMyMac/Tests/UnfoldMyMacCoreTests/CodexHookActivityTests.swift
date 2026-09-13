import Foundation
import Testing
@testable import UnfoldMyMacCore

@Test func codexLifecycleTracksWorkApprovalCompletionAndExpiry() {
    let now = Date()
    var record = CodexHookActivity(session: "session", event: "SessionStart", timestamp: now)
    #expect(record.state(at: now) == .idle)
    for (index, event) in ["UserPromptSubmit", "PermissionRequest", "PostToolUse", "Stop"].enumerated() {
        record.receive(event: event, turn: "turn", tool: "tool", at: now.addingTimeInterval(Double(index + 1)))
        #expect(record.state(at: record.timestamp) == [.working, .waiting, .working, .completed][index])
    }
    record.receive(event: "Stop", turn: "turn", tool: nil, at: now.addingTimeInterval(5))
    record.receive(event: "PostToolUse", turn: "turn", tool: "tool", at: now.addingTimeInterval(6))
    #expect(record.completedTurns == 1)
    #expect(record.toolEvents == 1)
    #expect(record.state(at: now.addingTimeInterval(6)) == .completed)
    #expect(record.state(at: now.addingTimeInterval(306)) == .idle)
    record.receive(event: "UserPromptSubmit", turn: "next", tool: nil, at: now.addingTimeInterval(7))
    record.receive(event: "Interrupt", turn: "next", tool: nil, at: now.addingTimeInterval(8))
    record.receive(event: "PreToolUse", turn: "next", tool: "late", at: now.addingTimeInterval(9))
    #expect(record.state(at: now.addingTimeInterval(9)) == .interrupted)
    record.receive(event: "UserPromptSubmit", turn: "older", tool: nil, at: now)
    #expect(record.event == "Interrupt")
}

@Test func codexHookDeduplicationRemainsBoundedAndOldRecordsDecode() throws {
    let now = Date()
    var record = CodexHookActivity(session: "s", event: "SessionStart", timestamp: now)
    for index in 0..<200 {
        record.receive(event: "PostToolUse", turn: "t\(index)", tool: "x\(index)", at: now)
        record.receive(event: "Stop", turn: "t\(index)", tool: nil, at: now)
    }
    #expect(record.completedTurns == 200)
    #expect(record.completedIDs.count == 128)
    #expect(record.toolIDs.count == 128)
    let data = try JSONEncoder().encode(record)
    #expect(try JSONDecoder().decode(CodexHookActivity.self, from: data).completedTurns == 200)
}
