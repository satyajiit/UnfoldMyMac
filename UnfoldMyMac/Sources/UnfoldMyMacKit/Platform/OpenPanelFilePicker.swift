import AppKit

@MainActor final class OpenPanelFilePicker: FilePicking {
    func pick(_ request: FilePickerRequest, completion: @escaping @MainActor (URL?) -> Void) {
        let panel = NSOpenPanel()
        if let title = request.title { panel.title = title }
        if let prompt = request.prompt { panel.prompt = prompt }
        if let message = request.message { panel.message = message }
        panel.allowedContentTypes = request.types
        panel.canChooseDirectories = request.directories; panel.canChooseFiles = !request.directories
        panel.allowsMultipleSelection = false
        panel.directoryURL = request.directoryURL
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            let url = response == .OK ? panel.url : nil
            Task { @MainActor in completion(url) }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: handler) }
        else { panel.begin(completionHandler: handler) }
    }
}
