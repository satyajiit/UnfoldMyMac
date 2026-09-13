import AppKit

@MainActor final class SystemWorkspace: WorkspaceOpening {
    nonisolated init() {}
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
    func copyToPasteboard(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    func showDesktop() {
        NSWorkspace.shared.hideOtherApplications()
        // Hiding this app would also hide its wallpaper windows. Only minimize its normal windows.
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.miniaturizable) {
            window.miniaturize(nil)
        }
    }
}
