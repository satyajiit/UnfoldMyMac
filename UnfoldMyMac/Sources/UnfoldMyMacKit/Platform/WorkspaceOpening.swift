import Foundation

/// Opens URLs and performs desktop actions. Views receive it through the environment; models through injection.
@MainActor protocol WorkspaceOpening: AnyObject {
    func open(_ url: URL)
    /// Replaces the general pasteboard's contents with `text`.
    func copyToPasteboard(_ text: String)
    /// Hides other apps and minimizes this app's ordinary windows, leaving its desktop surfaces visible.
    func showDesktop()
}

extension WorkspaceOpening {
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture") { open(url) }
    }
}
