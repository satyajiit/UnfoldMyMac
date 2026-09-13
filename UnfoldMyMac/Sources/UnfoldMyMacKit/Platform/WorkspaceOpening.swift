import Foundation

/// Opens URLs and system settings panes. Views receive it through the environment; models through injection.
@MainActor protocol WorkspaceOpening: AnyObject {
    func open(_ url: URL)
    /// Replaces the general pasteboard's contents with `text`.
    func copyToPasteboard(_ text: String)
}

extension WorkspaceOpening {
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture") { open(url) }
    }
}
