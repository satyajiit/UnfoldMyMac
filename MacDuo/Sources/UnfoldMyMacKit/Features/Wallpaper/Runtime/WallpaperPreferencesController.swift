import Observation
import UnfoldMyMacCore

/// The persisted wallpaper preferences and every mutation of them.
@MainActor @Observable final class WallpaperPreferencesController {
    private(set) var preferences: WallpaperPreferences
    @ObservationIgnored private let store: any PreferencesStore

    init(store: any PreferencesStore) {
        self.store = store
        preferences = store.load(WallpaperPreferences.key)
    }
    var enabled: Bool { preferences.enabled }
    func enable(templateID: String) { preferences.templateID = templateID; preferences.enabled = true; save() }
    /// `save` false records a runtime failure without turning a chosen wallpaper off across restarts.
    func disable(save persist: Bool = true) {
        preferences.enabled = false
        if persist { save() }
    }
    func setMaximumFPS(_ fps: Int) { preferences.maximumFPS = fps == 30 ? 30 : 60; save() }
    func setCustomBackground(_ value: Bool) { preferences.customBackground = value; save() }
    private func save() { store.save(preferences, for: WallpaperPreferences.key) }
}
