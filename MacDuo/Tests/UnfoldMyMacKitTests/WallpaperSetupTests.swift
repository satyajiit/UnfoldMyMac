import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func templateSetupIsRequiredTransactionalAndScopedToEachTemplate() throws {
    let suite = "template-setup-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let github = try #require(registry.templates.first { $0.id == "github-after-hours" })
    var second = github; second.id = "another-github-city"
    let setup = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults))
    var applied: String?
    setup.onApply = { applied = $0 }
    #expect(!setup.isReady(github))
    #expect(!setup.isReady(second))
    setup.open(github, applyAfterSetup: true)
    setup.finish()
    #expect(setup.request != nil && applied == nil)
    setup.draft["github-profile"] = .init(enabled: true, username: "alice")
    #expect(setup.draftReady && !setup.isReady(github))
    setup.cancel()
    #expect(!setup.isReady(github) && setup.configuration(.githubProfile, for: github.id).username == nil)
    setup.open(github, applyAfterSetup: true)
    setup.draft["github-profile"] = .init(enabled: true, username: "alice")
    setup.finish()
    #expect(applied == github.id && setup.request == nil)
    #expect(setup.isReady(github) && !setup.isReady(second))
    setup.open(second)
    setup.draft["github-profile"] = .init(enabled: true, username: "bob")
    setup.finish()
    let restored = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults))
    #expect(restored.configuration(.githubProfile, for: github.id).username == "alice")
    #expect(restored.configuration(.githubProfile, for: second.id).username == "bob")
    setup.open(github)
    setup.draft["github-profile"] = .init()
    setup.finish()
    #expect(!setup.isReady(github) && setup.isReady(second))
}

@Test @MainActor func legacyGlobalGitHubDoesNotBypassTemplateSetup() throws {
    let suite = "template-migration-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let legacy = try JSONEncoder().encode(WallpaperPreferences())
    var object = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
    object["githubUsername"] = "previous-global-user"
    defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "unfoldmymac.wallpaper.v1")
    let setup = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults))
    #expect(setup.configuration(.githubProfile, for: "github-after-hours").username == nil)
    #expect(!setup.configuration(.codexActivity, for: "codex-mission-control").enabled)
    #expect(setup.configuration(.codexHistory, for: "codex-foundry").enabled)
}

@Test @MainActor func wallpaperApplyRequestsItsOwnSetupAndLeavesCurrentDesktopRunning() throws {
    let suite = "template-apply-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(), surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context())
    model.start(); model.apply()
    defer { model.shutdown() }
    #expect(model.enabled && model.activePipeline?.template.id == "pulse")
    model.select("github-after-hours"); model.apply()
    #expect(model.activePipeline?.template.id == "pulse")
    #expect(model.setup.request?.template.id == "github-after-hours")
    #expect(model.setup.request?.applyAfterSetup == true)
    model.setup.cancel()
    #expect(model.activePipeline?.template.id == "pulse")
    model.select("codex-mission-control"); model.apply()
    #expect(model.setup.request?.template.id == "codex-mission-control")
    #expect(!model.setup.draftReady)
    model.setup.cancel()
    model.select("lights-out"); model.apply()
    #expect(model.setup.request == nil && model.activePipeline?.template.id == "lights-out")
}

@Test @MainActor func templateSetupSchemaRejectsDuplicatesAndKeepsPlainScenesCompatible() throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    var template = try #require(registry.templates.first { $0.id == "pulse" })
    #expect(WallpaperSetupController.isReady(template, connections: [:]))
    template.setup = [.init(kind: .githubProfile, required: true), .init(kind: .githubProfile, required: false)]
    #expect(throws: WallpaperError.invalidTemplate) { try template.validated() }
    template.setup = [.init(kind: .githubProfile, required: true)]
    #expect(!WallpaperSetupController.isReady(template, connections: ["github-profile": .init(enabled: true, username: "../bad")]))
    template.setup = [.init(kind: .toolFile, required: false)]
    #expect(WallpaperSetupController.isReady(template, connections: [:]))
}
