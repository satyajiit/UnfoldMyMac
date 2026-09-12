import Observation

/// Owns navigation for the main window. Leaving the effects library, or hiding the window, ends a running preview;
/// the wallpaper preview renders only while its page is visible.
@MainActor @Observable final class AppShellModel: EffectsNavigating {
    var route: AppRoute? = .effects {
        didSet {
            if route != .effects { effectsPath = []; effects.stopPreview() }
            syncBrowsing()
        }
    }
    var effectsPath: [EffectsDestination] = [] {
        didSet { if !effectsPath.isEmpty { effects.stopPreview() } }
    }
    private(set) var windowVisible = false
    @ObservationIgnored private let effects: UnfoldMyMacModel
    @ObservationIgnored private let wallpaper: any WallpaperBrowsing

    init(effects: UnfoldMyMacModel, wallpaper: any WallpaperBrowsing) {
        self.effects = effects; self.wallpaper = wallpaper
        effects.navigator = self
    }
    func show(_ route: AppRoute) { self.route = route }
    func showEffectSettings() { route = .effects; effectsPath = [.settings] }
    func showEffectsLibrary() { route = .effects; effectsPath = [] }
    func windowDidShow() { windowVisible = true; effects.setWindowVisible(true); syncBrowsing() }
    func windowDidHide() { windowVisible = false; effects.stopPreview(); effects.setWindowVisible(false); syncBrowsing() }
    private func syncBrowsing() { wallpaper.setBrowsing(windowVisible && route == .wallpaper) }
}
