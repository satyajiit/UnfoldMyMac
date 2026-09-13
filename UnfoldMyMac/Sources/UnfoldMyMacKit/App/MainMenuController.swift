import AppKit
import UnfoldMyMacCore

@MainActor final class MainMenuController: NSObject {
    private let showSettings: () -> Void
    private let checkForUpdates: () -> Void
    init(showSettings: @escaping () -> Void, checkForUpdates: @escaping () -> Void) {
        self.showSettings = showSettings; self.checkForUpdates = checkForUpdates
    }

    func install() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        // Apple's order: check for updates sits above Settings, with no key equivalent. It stays
        // enabled even when updating is impossible, because the click lands on the About card that
        // explains why — more use than a greyed-out item.
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(update(_:)), keyEquivalent: "")
        updates.target = self; appMenu.addItem(updates)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(settings(_:)), keyEquivalent: ",")
        settings.target = self; appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(AppIdentity.name)", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self; appMenu.addItem(quit)
        let windowMenu = NSMenu(title: "Window")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(windowItem); NSApp.windowsMenu = windowMenu; NSApp.mainMenu = main
    }
    @objc private func settings(_ sender: Any?) { showSettings() }
    @objc private func update(_ sender: Any?) { checkForUpdates() }
    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }
}
