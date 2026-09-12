import Foundation
import UniformTypeIdentifiers

struct FilePickerRequest: Sendable {
    var title: String?
    var prompt: String?
    var message: String?
    var types: [UTType]
    var directories = false
    var directoryURL: URL?
}

/// Presents a file chooser; models never build panels themselves.
@MainActor protocol FilePicking: AnyObject {
    func pick(_ request: FilePickerRequest, completion: @escaping @MainActor (URL?) -> Void)
}
