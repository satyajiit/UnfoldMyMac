import AppKit
import UnfoldMyMacCore

@MainActor final class MainWindowController: NSObject, NSWindowDelegate {
    static let autosaveName = "UnfoldMyMacMainWindow"
    static let legacyAutosaveName = "LumaMainWindow"
    private let shell: AppShellModel
    private let makeContent: () -> NSView
    private var window: NSWindow?

    init(shell: AppShellModel, makeContent: @escaping () -> NSView) {
        self.shell = shell; self.makeContent = makeContent
    }
    func show() {
        let window = self.window ?? makeWindow()
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        shell.windowDidShow()
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === window { shell.windowDidHide() }
    }
    func windowDidMiniaturize(_ notification: Notification) { shell.windowDidHide() }
    func windowDidDeminiaturize(_ notification: Notification) { shell.windowDidShow() }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = AppIdentity.name
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.contentMinSize = NSSize(width: 900, height: 620)
        window.contentView = makeContent()
        window.delegate = self
        window.center()
        migrateLegacyFrame()
        window.setFrameAutosaveName(Self.autosaveName)
        self.window = window
        return window
    }
    private func migrateLegacyFrame() {
        let defaults = UserDefaults.standard
        let key = "NSWindow Frame \(Self.autosaveName)", legacyKey = "NSWindow Frame \(Self.legacyAutosaveName)"
        if defaults.object(forKey: key) == nil, let legacy = defaults.string(forKey: legacyKey) { defaults.set(legacy, forKey: key) }
    }
}
