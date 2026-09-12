import AppKit
import SwiftUI
import UnfoldMyMacCore

/// The application delegate: builds both features from one set of dependencies and owns the AppKit chrome.
@MainActor final class AppController: NSObject, NSApplicationDelegate {
    private let dependencies: AppDependencies
    private let effects: EffectsModel
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
        let covers = CoverImageStore()
        let window = MainWindowController(shell: shell) {
            NSHostingView(rootView: UnfoldMyMacView(shell: shell, effects: effects, wallpaper: wallpaper)
                .environment(\.workspace, dependencies.workspace).environment(\.filePicker, dependencies.filePicker)
                .environment(\.appInfo, .live).environment(\.coverImages, covers))
        }
        self.effects = effects; self.wallpaper = wallpaper; self.shell = shell; self.window = window
        menu = MainMenuController(showSettings: { shell.show(.settings); window.show() })
        statusMenu = StatusMenuController(effects: effects, wallpaper: wallpaper, shell: shell, window: window, workspace: dependencies.workspace)
        previewPanel = PreviewPanelController(model: effects, displays: dependencies.displays)
        appearance = AppearanceController(model: effects)
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        var timeline = LaunchTimeline()
        UnfoldMyMacType.register(); timeline.mark("fonts")
        menu.install(); statusMenu.install(); timeline.mark("menus")
        dependencies.environment.start(); timeline.mark("environment")
        effects.start(); timeline.mark("effects")
        wallpaper.start(); timeline.mark("wallpaper")
        appearance.start(); previewPanel.start(); timeline.mark("appearance")
        window.show(); timeline.mark("window")
        timeline.report(gpu: dependencies.gpu)
        BrandAssets.installDockIconIfUnbundled()
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
