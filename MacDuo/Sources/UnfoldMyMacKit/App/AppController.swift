import AppKit
import SwiftUI
import UnfoldMyMacCore

/// The application delegate: builds both features from one set of dependencies and owns the AppKit chrome.
@MainActor final class AppController: NSObject, NSApplicationDelegate {
    private let dependencies: AppDependencies
    private let effects: UnfoldMyMacModel
    private let wallpaper: WallpaperModel
    private let shell: AppShellModel
    private let window: MainWindowController
    private let menu: MainMenuController
    private let statusMenu: StatusMenuController
    private let previewPanel: PreviewPanelController
    private let appearance: AppearanceController

    init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
        let effects = EffectsFeature.make(dependencies: dependencies)
        let wallpaper = WallpaperFeature.make(dependencies: dependencies)
        let shell = AppShellModel(effects: effects, wallpaper: wallpaper)
        let window = MainWindowController(shell: shell) {
            NSHostingView(rootView: UnfoldMyMacView(shell: shell, effects: effects, wallpaper: wallpaper)
                .environment(\.workspace, dependencies.workspace).environment(\.appInfo, .live))
        }
        self.effects = effects; self.wallpaper = wallpaper; self.shell = shell; self.window = window
        menu = MainMenuController(showSettings: { shell.show(.settings); window.show() })
        statusMenu = StatusMenuController(effects: effects, wallpaper: wallpaper, shell: shell, window: window)
        previewPanel = PreviewPanelController(model: effects, displays: dependencies.displays)
        appearance = AppearanceController(model: effects)
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchStart = ContinuousClock.now
        defer {
            if ProcessInfo.processInfo.environment["UNFOLDMYMAC_LAUNCH_TIMING"] == "1" {
                let shaders = dependencies.gpu.map { "\($0.libraries.compiledFromSource) shader units compiled from source, \($0.libraries.loadedPrecompiled) precompiled, \($0.pipelines.builtCount) pipeline states" } ?? "no GPU"
                print("LAUNCH applicationDidFinishLaunching→showWindow: \(launchStart.duration(to: .now)); \(shaders)"); fflush(nil)
            }
        }
        UnfoldMyMacType.register()
        if let logo = BrandAssets.logo { NSApp.applicationIconImage = logo }
        menu.install(); statusMenu.install()
        dependencies.environment.start()
        effects.start(); wallpaper.start()
        appearance.start(); previewPanel.start()
        window.show()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.show()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        previewPanel.stop(); appearance.stop(); statusMenu.stop()
        effects.shutdown(); wallpaper.shutdown(); dependencies.environment.stop()
    }
}
