import AppKit
import UnfoldMyMacCore

@MainActor final class MainMenuController: NSObject {
    private let showSettings: () -> Void
    init(showSettings: @escaping () -> Void) { self.showSettings = showSettings }

    func install() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
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
    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }
}
