import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor enum WallpaperFileActions {
    static func chooseClaudeFolder(current: String?, action: @escaping @MainActor (URL) -> Void) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.directoryURL = current.map { URL(fileURLWithPath: $0) } ?? WallpaperPaths.defaultClaudeRoot
        panel.message = "Choose the Claude projects folder, or one project’s log folder."
        panel.begin { response in
            if response == .OK, let url = panel.url { action(url) }
        }
    }
    static func chooseToolFile(action: @escaping @MainActor (URL) -> Void) {
        chooseFile(types: [.json], action: action)
    }
    static func importTemplate(_ model: WallpaperModel) {
        chooseFile(types: [.json]) { model.importTemplate($0) }
    }
    static func chooseBackground(_ model: WallpaperModel) {
        chooseFile(types: [.image]) { url in
            Task {
                do { try await WallpaperImageImport.save(url); model.setCustomBackground(true) }
                catch { model.error = error.localizedDescription }
            }
        }
    }
    static func copyClaudeHooks() {
        let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "' --wallpaper-claude-hook"
        let events = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "StopFailure", "SessionEnd"]
        let entry: [[String: Any]] = [["hooks": [["type": "command", "command": quoted, "timeout": 3]]]]
        let config = ["hooks": Dictionary(uniqueKeysWithValues: events.map { ($0, entry) })]
        if let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { copy(text) }
    }
    static func copyToolExample() {
        let date = Date.now.ISO8601Format()
        copy("""
        {"timestamp":"\(date)","numbers":{"tool.value":42},"text":{"tool.label":"BUILD STATUS","tool.status":"ALL SYSTEMS GO."},"status":"Live"}
        """)
    }
    private static func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    private static func chooseFile(types: [UTType], action: @escaping @MainActor (URL) -> Void) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = types; panel.allowsMultipleSelection = false
        panel.begin { response in if response == .OK, let url = panel.url { action(url) } }
    }
}

private actor WallpaperImageImport {
    static func save(_ url: URL) async throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2560] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: WallpaperPaths.root, withIntermediateDirectories: true)
        try (data as Data).write(to: WallpaperPaths.background, options: .atomic)
    }
}
