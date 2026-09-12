import Foundation
import Testing
import UnfoldMyMacCore

// L11: parameters for effects that no longer exist are pruned.
@Test func settingsReconcilePrunesParametersOfUnknownEffects() {
    var settings = UnfoldMyMacSettings()
    settings.parameters["frost"] = .init(strength: 0.5)
    settings.parameters["import.gone"] = .init(strength: 0.2, reveal: .burst)
    let pruned = settings.reconcile(effects: [.frost, .veil])
    #expect(pruned)
    #expect(settings.parameters.keys.sorted() == ["frost"])
    let prunedAgain = settings.reconcile(effects: [.frost, .veil])
    #expect(!prunedAgain, "Nothing left to prune")
}

// L11: once migrated, the pre-rename keys are removed so they can never shadow the current value.
@Test @MainActor func legacyKeysAreRemovedAfterMigration() throws {
    let name = "UnfoldMyMacTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(110.0, forKey: "activation"); defaults.set(2, forKey: "style")
    var legacy = UnfoldMyMacSettings(); legacy.effect = .fade
    defaults.set(try JSONEncoder().encode(legacy), forKey: DefaultsSettingsStore.legacyKey)
    let store = DefaultsSettingsStore(defaults: defaults)
    #expect(store.load().effect == .fade)
    #expect(defaults.data(forKey: DefaultsSettingsStore.key) != nil)
    #expect(defaults.object(forKey: DefaultsSettingsStore.legacyKey) == nil)
    #expect(defaults.object(forKey: "activation") == nil && defaults.object(forKey: "style") == nil)
    #expect(store.load().effect == .fade)
}
