import Foundation
import UniformTypeIdentifiers
import UnfoldMyMacCore

/// The file choosers the wallpaper pages present through the injected `FilePicking` service.
enum WallpaperFileRequests {
    static let template = FilePickerRequest(title: "Import a wallpaper template", prompt: "Import", types: [.json])
    static let background = FilePickerRequest(title: "Choose a background image", prompt: "Choose",
        message: "Your image is copied into \(AppIdentity.name) and shared by every image-based scene.", types: [.image])
    static let toolFile = FilePickerRequest(title: "Choose a data file", prompt: "Choose", types: [.json])
    static func claudeFolder(current: String?) -> FilePickerRequest {
        FilePickerRequest(message: "Choose the Claude projects folder, or one project’s log folder.", types: [], directories: true,
                          directoryURL: current.map { URL(fileURLWithPath: $0) } ?? WallpaperPaths.defaultClaudeRoot)
    }
}
