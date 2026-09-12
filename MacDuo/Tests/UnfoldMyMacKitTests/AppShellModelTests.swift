import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func shellSyncsWallpaperBrowsingWithRouteAndWindowAndEndsPreviews() {
    let store = InMemoryPreferencesStore(), registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), makeCapture: { FakeCapture() })
    let model = makeModel(store: store, registry: registry, session: session)
    defer { model.shutdown() }
    let wallpaper = FakeWallpaperBrowsing()
    let shell = AppShellModel(effects: model, wallpaper: wallpaper)
    shell.show(.wallpaper)
    #expect(!wallpaper.browsing, "The wallpaper preview waits for a visible window")
    shell.windowDidShow()
    #expect(wallpaper.browsing)
    shell.show(.effects)
    #expect(!wallpaper.browsing)
    shell.show(.wallpaper)
    #expect(wallpaper.browsing)
    shell.windowDidHide()
    #expect(!wallpaper.browsing)
    shell.windowDidShow(); shell.show(.settings)
    model.togglePreview(for: .curtains)
    #expect(shell.route == .effects && shell.effectsPath.isEmpty && model.isPreviewing, "A preview brings the library forward")
    shell.windowDidHide()
    #expect(!model.isPreviewing, "Hiding the window ends the preview")
}
