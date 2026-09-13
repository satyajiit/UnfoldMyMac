import Observation

/// Owns navigation for the main window. Leaving the effects library, or hiding the window, ends a running preview;
/// the wallpaper preview renders only while its page is visible.
@MainActor @Observable final class AppShellModel: EffectsNavigating {
    /// One window-level presenter decides which sheet is on screen, so a background discovery can
    /// never replace a setup sheet the user is halfway through.
    enum Sheet: Identifiable, Equatable {
        case wallpaperSetup(String)
        case update
        var id: String {
            switch self {
            case .wallpaperSetup(let request): "wallpaper.\(request)"
            case .update: "update"
            }
        }
    }

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
    @ObservationIgnored private let effects: EffectsModel
    @ObservationIgnored private let wallpaper: any WallpaperBrowsing
    @ObservationIgnored private let updates: (any UpdatePrompting)?

    init(effects: EffectsModel, wallpaper: any WallpaperBrowsing, updates: (any UpdatePrompting)? = nil) {
        self.effects = effects; self.wallpaper = wallpaper; self.updates = updates
        effects.navigator = self
    }

    /// Wallpaper setup wins: it is a task the user started, and the update is not going anywhere.
    func sheet(wallpaperRequest: String?) -> Sheet? {
        if let wallpaperRequest { return .wallpaperSetup(wallpaperRequest) }
        return updates?.promptPending == true ? .update : nil
    }
    func dismissSheet(wallpaperRequest: String?, cancelWallpaper: () -> Void) {
        if wallpaperRequest != nil { cancelWallpaper() } else { updates?.dismissPrompt() }
    }
    func show(_ route: AppRoute) { self.route = route }
    func showEffectSettings() { route = .effects; effectsPath = [.settings] }
    func showEffectsLibrary() { route = .effects; effectsPath = [] }
    func windowDidShow() {
        windowVisible = true; effects.setWindowVisible(true); syncBrowsing()
        updates?.windowDidBecomeVisible()
    }
    func windowDidHide() { windowVisible = false; effects.stopPreview(); effects.setWindowVisible(false); syncBrowsing() }
    private func syncBrowsing() { wallpaper.setBrowsing(windowVisible && (route == .wallpaper || route == .scenes)) }
}
