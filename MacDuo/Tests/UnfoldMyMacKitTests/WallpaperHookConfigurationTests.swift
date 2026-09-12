import Foundation
import Testing
@testable import UnfoldMyMacKit

// Phase 8: the pasteboard text the setup sheets offer is built by a pure helper and copied through the workspace seam.
@Test func hookConfigurationTextIsValidJSONThatNamesThisExecutable() throws {
    let text = WallpaperHookConfiguration.claudeHooks(executable: "/Applications/It's Here.app/Contents/MacOS/UnfoldMyMac")
    let object = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: [String: [[String: Any]]]])
    let hooks = try #require(object["hooks"])
    #expect(Set(hooks.keys) == Set(WallpaperHookConfiguration.claudeEvents))
    let command = try #require(((hooks["Stop"]?.first?["hooks"] as? [[String: Any]])?.first?["command"]) as? String)
    #expect(command == "'/Applications/It'\\''s Here.app/Contents/MacOS/UnfoldMyMac' --wallpaper-claude-hook")
    let example = try #require(try JSONSerialization.jsonObject(with: Data(WallpaperHookConfiguration.toolExample(date: Date(timeIntervalSince1970: 0)).utf8)) as? [String: Any])
    #expect(example["timestamp"] as? String == "1970-01-01T00:00:00Z" && (example["numbers"] as? [String: Double])?["tool.value"] == 42)
}

@Test @MainActor func workspaceFakeRecordsPasteboardCopies() {
    let workspace = FakeWorkspace()
    workspace.copyToPasteboard("hello")
    #expect(workspace.copied == ["hello"])
}
