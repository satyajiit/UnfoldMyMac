import AppKit
import SwiftUI
import UnfoldMyMacCore

/// The sole composition root. Platform dependencies do not escape into SwiftUI views.
@MainActor public final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model: UnfoldMyMacModel
    private let wallpaper: WallpaperModel
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var previewPanel: NSPanel?
    public override init() {
        let wallpaper = WallpaperModel(systemBackdrop: WallpaperSystemBackdrop())
        self.wallpaper = wallpaper
        let registry = EffectRegistry.builtIn()
        AppSupportPaths.migrateLegacyArtwork()
        let library = ArtworkLibrary()
        for artwork in library.definitions { try? registry.register(.artwork(artwork)) }
        let session = EffectSession(registry: registry, host: EffectHost(), makeCapture: {
            DesktopCapture(includingWindows: { wallpaper.desktopWindowIDs })
        })
        model = UnfoldMyMacModel(store: DefaultsSettingsStore(), registry: registry, sensorFactory: { LidSensor() }, displays: DisplayEnvironment(), session: session, artworkLibrary: library)
        super.init()
    }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let launchStart = ContinuousClock.now
        defer {
            if ProcessInfo.processInfo.environment["UNFOLDMYMAC_LAUNCH_TIMING"] == "1" {
                let elapsed = launchStart.duration(to: .now)
                print("LAUNCH applicationDidFinishLaunching→showWindow: \(elapsed)"); fflush(nil)
            }
        }
        UnfoldMyMacType.register()
        if let logo = BrandAssets.logo { NSApp.applicationIconImage = logo }
        installMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: UnfoldMyMacIcon.brand.rawValue, accessibilityDescription: AppIdentity.name)
        item.button?.target = self; item.button?.action = #selector(showQuickMenu)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        model.onStatusChanged = { [weak self] in self?.refreshStatus() }
        model.onPreviewChanged = { [weak self] in self?.refreshPreview() }
        model.onAppearanceChanged = { [weak self] in self?.applyAppearance() }
        model.start(); wallpaper.start(); applyAppearance(); refreshStatus(); showWindow()
    }
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    public func applicationWillTerminate(_ notification: Notification) { model.shutdown(); wallpaper.shutdown() }
    public func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === mainWindow { model.stopPreview(); wallpaper.setBrowsing(false) }
    }
    public func windowDidMiniaturize(_ notification: Notification) { model.stopPreview(); wallpaper.setBrowsing(false) }
    public func windowDidDeminiaturize(_ notification: Notification) { wallpaper.setBrowsing(model.route == .wallpaper) }
    private func installMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(AppIdentity.name)", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; appMenu.addItem(quit)
        let windowMenu = NSMenu(title: "Window")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: ""); windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(windowItem); NSApp.windowsMenu = windowMenu; NSApp.mainMenu = main
    }
    @objc private func showQuickMenu() {
        let menu = NSMenu()
        let summary = NSMenuItem(title: model.status, action: nil, keyEquivalent: "")
        summary.isEnabled = false; menu.addItem(summary); menu.addItem(.separator())
        add(menu, title: model.enabled ? "Turn Effect Off" : "Turn Effect On", action: #selector(toggle))
        for category in EffectCategory.allCases {
            let group = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: category.title)
            for descriptor in model.registry.descriptors where descriptor.category == category {
                let item = NSMenuItem(title: descriptor.title, action: #selector(selectEffect(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = descriptor.id.rawValue
                item.state = descriptor.id == model.settings.effect ? .on : .off
                submenu.addItem(item)
            }
            group.submenu = submenu; menu.addItem(group)
        }
        if model.isPreviewing { add(menu, title: "Stop Preview", action: #selector(stopPreview)) }
        menu.addItem(.separator())
        add(menu, title: "Wallpaper…", action: #selector(showWallpaper))
        if wallpaper.enabled { add(menu, title: "Stop Wallpaper", action: #selector(stopWallpaper)) }
        menu.addItem(.separator())
        add(menu, title: "Open \(AppIdentity.name)…", action: #selector(showWindow))
        add(menu, title: "Settings…", action: #selector(showSettings))
        menu.addItem(.separator()); add(menu, title: "Quit \(AppIdentity.name)", action: #selector(quit))
        statusItem?.menu = menu; statusItem?.button?.performClick(nil); statusItem?.menu = nil
    }
    private func add(_ menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
    }
    @objc private func toggle() { model.setEnabled(!model.enabled) }
    @objc private func selectEffect(_ item: NSMenuItem) {
        if let id = item.representedObject as? String { model.selectEffect(EffectID(rawValue: id)) }
    }
    @objc private func stopPreview() { model.stopPreview() }
    @objc private func showWallpaper() { model.route = .wallpaper; showWindow() }
    @objc private func stopWallpaper() { wallpaper.stopWallpaper() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showSettings() { model.route = .settings; showWindow() }
    @objc private func showWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = AppIdentity.name
            window.titleVisibility = .hidden
            window.toolbarStyle = .unifiedCompact
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.contentMinSize = NSSize(width: 800, height: 580)
            window.contentView = NSHostingView(rootView: UnfoldMyMacView(model: model, wallpaper: wallpaper))
            window.delegate = self
            window.center()
            let defaults = UserDefaults.standard
            if defaults.object(forKey: "NSWindow Frame UnfoldMyMacMainWindow") == nil, let legacy = defaults.string(forKey: "NSWindow Frame LumaMainWindow") {
                defaults.set(legacy, forKey: "NSWindow Frame UnfoldMyMacMainWindow")
            }
            window.setFrameAutosaveName("UnfoldMyMacMainWindow")
            mainWindow = window
        }
        if mainWindow?.isMiniaturized == true { mainWindow?.deminiaturize(nil) }
        mainWindow?.makeKeyAndOrderFront(nil)
        wallpaper.setBrowsing(model.route == .wallpaper)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func refreshStatus() {
        statusItem?.button?.title = model.settings.showAngle ? " \(model.angleLabel)" : ""
        statusItem?.button?.toolTip = "\(AppIdentity.name) · \(model.status)"
    }
    private func applyAppearance() {
        switch model.settings.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    private func refreshPreview() {
        guard model.isPreviewing else { previewPanel?.orderOut(nil); return }
        if previewPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200), styleMask: [.titled, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "\(AppIdentity.name) Preview"
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.level = NSWindow.Level(rawValue: EffectHost.level.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: PreviewControls(model: model))
            previewPanel = panel
        }
        if let panel = previewPanel, let screen = DisplayEnvironment.usableBuiltInScreen() {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 40))
            panel.makeKeyAndOrderFront(nil)
        }
    }
}
