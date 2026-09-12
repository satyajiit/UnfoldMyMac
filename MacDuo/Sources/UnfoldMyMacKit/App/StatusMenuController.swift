import AppKit
import Observation
import UnfoldMyMacCore

/// The menu-bar item: a live angle readout and the quick menu.
@MainActor final class StatusMenuController: NSObject {
    private final class ActionBox { let action: QuickMenu.Action; init(_ action: QuickMenu.Action) { self.action = action } }
    private let effects: UnfoldMyMacModel
    private let wallpaper: WallpaperModel
    private let shell: AppShellModel
    private let window: MainWindowController
    private var item: NSStatusItem?
    private var observation: Task<Void, Never>?

    init(effects: UnfoldMyMacModel, wallpaper: WallpaperModel, shell: AppShellModel, window: MainWindowController) {
        self.effects = effects; self.wallpaper = wallpaper; self.shell = shell; self.window = window
    }
    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: UnfoldMyMacIcon.brand.rawValue, accessibilityDescription: AppIdentity.name)
        item.button?.target = self; item.button?.action = #selector(showQuickMenu(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
        let effects = self.effects
        observation = Task { [weak self] in
            for await (title, status) in Observations({ (effects.settings.showAngle ? " \(effects.angleLabel)" : "", effects.status) }) {
                self?.apply(title: title, status: status)
            }
        }
    }
    func stop() { observation?.cancel(); observation = nil }
    isolated deinit { stop() }

    private func apply(title: String, status: String) {
        guard let button = item?.button else { return }
        if button.title != title { button.title = title }
        button.toolTip = "\(AppIdentity.name) · \(status)"
    }
    @objc private func showQuickMenu(_ sender: Any?) {
        let state = QuickMenuState(status: effects.status, effectEnabled: effects.enabled, isPreviewing: effects.isPreviewing,
                                   selectedEffect: effects.settings.effect, wallpaperEnabled: wallpaper.enabled, effects: effects.registry.descriptors)
        let menu = makeMenu(QuickMenuBuilder.menu(for: state).items)
        item?.menu = menu; item?.button?.performClick(nil); item?.menu = nil
    }
    private func makeMenu(_ items: [QuickMenu.Item]) -> NSMenu {
        let menu = NSMenu()
        for entry in items {
            switch entry {
            case .label(let title):
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); item.isEnabled = false; menu.addItem(item)
            case .separator: menu.addItem(.separator())
            case .submenu(let title, let children):
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let submenu = makeMenu(children); submenu.title = title; item.submenu = submenu; menu.addItem(item)
            case .action(let title, let action, let checked):
                let item = NSMenuItem(title: title, action: #selector(performQuickMenuAction(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = ActionBox(action); item.state = checked ? .on : .off
                menu.addItem(item)
            }
        }
        return menu
    }
    @objc private func performQuickMenuAction(_ sender: NSMenuItem) {
        guard let action = (sender.representedObject as? ActionBox)?.action else { return }
        switch action {
        case .toggleEffect: effects.setEnabled(!effects.enabled)
        case .selectEffect(let id): effects.selectEffect(id)
        case .stopPreview: effects.stopPreview()
        case .showWallpaper: shell.show(.wallpaper); window.show()
        case .stopWallpaper: wallpaper.stopWallpaper()
        case .openApp: window.show()
        case .showSettings: shell.show(.settings); window.show()
        case .quit: NSApp.terminate(nil)
        }
    }
}
