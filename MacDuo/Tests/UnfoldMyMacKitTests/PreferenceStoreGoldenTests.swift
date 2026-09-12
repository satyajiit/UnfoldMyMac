import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

// Payloads exactly as earlier releases wrote them. Changing a key name or a field's spelling breaks these on purpose.
private let settingsFixture = Data("""
{"effect":"curtains","activation":95.4,"completionFraction":0.8,"appearance":"dark","showAngle":false,\
"parameters":{"rise":{"strength":0.3,"reveal":"straight"},"frost":{"strength":2}}}
""".utf8)
private let wallpaperFixture = Data("""
{"enabled":true,"templateID":"codex-foundry","claudeConnected":true,"codexConnected":false,"claudeRoot":"/tmp/claude",\
"toolPath":"/tmp/tool.json","customBackground":true,"maximumFPS":45}
""".utf8)
private let connectionsFixture = Data("""
{"github-city":{"github-profile":{"enabled":true,"username":"octocat"}},"claude-current":{"claude-code":{"enabled":false,"path":"/tmp/x"}}}
""".utf8)

@Test @MainActor func preferenceKeysKeepTheirPersistedNames() {
    #expect(UnfoldMyMacSettings.key.name == "unfoldmymac.settings.v1")
    #expect(UnfoldMyMacSettings.key.legacyNames == ["luma.settings.v1", "activation", "style"])
    #expect(WallpaperPreferences.key.name == "unfoldmymac.wallpaper.v1")
    #expect(WallpaperSetupController.key.name == "unfoldmymac.wallpaper.connections.v1")
}

@Test @MainActor func settingsFixtureDecodesSanitizesAndRoundTrips() throws {
    let store = InMemoryPreferencesStore()
    store.set(settingsFixture, forKey: UnfoldMyMacSettings.key.name)
    let settings = store.load(UnfoldMyMacSettings.key)
    #expect(settings.effect == .curtains && settings.activation == 95 && settings.completionFraction == 0.8)
    #expect(settings.appearance == .dark && settings.showAngle == false)
    #expect(settings.parameters["rise"] == EffectParameters(strength: 0.3, reveal: .straight))
    #expect(settings.parameters["frost"]?.strength == 1, "Out-of-range strengths are clamped on load")
    store.save(settings, for: UnfoldMyMacSettings.key)
    #expect(store.load(UnfoldMyMacSettings.key) == settings)
}

@Test @MainActor func legacySettingsNameIsAdoptedOnce() {
    let store = InMemoryPreferencesStore()
    store.set(settingsFixture, forKey: "luma.settings.v1")
    let settings = store.load(UnfoldMyMacSettings.key)
    #expect(settings.effect == .curtains)
    #expect(store.data(forKey: UnfoldMyMacSettings.key.name) != nil && store.object(forKey: "luma.settings.v1") == nil)
}

@Test @MainActor func firstReleaseRawKeysMigrateAndAreRemoved() {
    let store = InMemoryPreferencesStore()
    store.setRaw(2, forKey: "style"); store.setRaw(110.0, forKey: "activation")
    let settings = store.load(UnfoldMyMacSettings.key)
    #expect(settings.effect == .veil && settings.activation == 110)
    #expect(store.object(forKey: "style") == nil && store.object(forKey: "activation") == nil)
    #expect(store.data(forKey: UnfoldMyMacSettings.key.name) != nil)
    let fresh = InMemoryPreferencesStore()
    #expect(fresh.load(UnfoldMyMacSettings.key) == UnfoldMyMacSettings(), "No data at all: the default, and nothing is written")
    #expect(fresh.storage.isEmpty)
}

@Test @MainActor func wallpaperFixtureDecodesAndSanitizesTheFrameRate() {
    let store = InMemoryPreferencesStore()
    store.set(wallpaperFixture, forKey: WallpaperPreferences.key.name)
    let preferences = store.load(WallpaperPreferences.key)
    #expect(preferences.enabled && preferences.templateID == "codex-foundry" && preferences.claudeConnected && preferences.codexConnected == false)
    #expect(preferences.claudeRoot == "/tmp/claude" && preferences.toolPath == "/tmp/tool.json" && preferences.customBackground)
    #expect(preferences.maximumFPS == 60, "Only 30 and 60 are valid ceilings")
    store.set(Data(#"{"maximumFPS":30}"#.utf8), forKey: WallpaperPreferences.key.name)
    let partial = store.load(WallpaperPreferences.key)
    #expect(partial.maximumFPS == 30 && partial.templateID == "pulse" && partial.codexConnected == nil)
}

@Test @MainActor func connectionsFixtureDecodesAndLegacyWallpaperPreferencesSeedThem() {
    let store = InMemoryPreferencesStore()
    store.set(connectionsFixture, forKey: WallpaperSetupController.key.name)
    let connections = store.load(WallpaperSetupController.key)
    #expect(connections["github-city"]?["github-profile"] == .init(enabled: true, username: "octocat"))
    #expect(connections["claude-current"]?["claude-code"] == .init(enabled: false, path: "/tmp/x"))

    let legacy = InMemoryPreferencesStore()
    legacy.set(wallpaperFixture, forKey: WallpaperPreferences.key.name)
    let seeded = legacy.load(WallpaperSetupController.key)
    #expect(seeded["codex-foundry"]?["codex-history"] == .init(enabled: false))
    #expect(seeded["codex-foundry"]?["tool-file"] == .init(enabled: true, path: "/tmp/tool.json"))
    #expect(seeded["claude-current"]?["claude-code"] == .init(enabled: true, path: "/tmp/claude"))
    #expect(seeded["daydream"]?["tool-file"]?.path == "/tmp/tool.json" && seeded["grok-horizon"]?["tool-file"]?.path == "/tmp/tool.json")
    #expect(legacy.data(forKey: WallpaperSetupController.key.name) != nil, "The migration result is written so it runs once")
    #expect(InMemoryPreferencesStore().load(WallpaperSetupController.key).isEmpty)
}
