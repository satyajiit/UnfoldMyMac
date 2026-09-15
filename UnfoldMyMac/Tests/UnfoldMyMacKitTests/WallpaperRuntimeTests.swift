import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor private func bundledTemplates() throws -> [WallpaperTemplate] {
    try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
}
private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

@Test func connectorRegistryCoversEverySetupKindAndValidatesConfigurations() throws {
    let registry = WallpaperConnectorRegistry.standard
    for kind in WallpaperConnectorID.bundled { #expect(registry.connector(kind.rawValue) != nil, Comment(rawValue: kind.rawValue)) }
    #expect(Set(registry.connectors.map(\.id)).count == registry.connectors.count)
    let github = try #require(registry.connector("github-profile"))
    #expect(!github.validate(.init(enabled: true)) && !github.validate(.init(enabled: false, username: "alice")))
    #expect(github.validate(.init(enabled: true, username: "alice")) && !github.validate(.init(enabled: true, username: "-bad")))
    let tool = try #require(registry.connector("tool-file"))
    #expect(!tool.validate(.init(enabled: true, path: "")) && tool.validate(.init(enabled: true, path: "/tmp/feed.json")))
    let http = try #require(registry.connector("http"))
    #expect(!http.validate(.init(enabled: true, path: "http://insecure.example/feed")) && http.validate(.init(enabled: true, path: "https://example.com/feed.json")))
    #expect(http.makeProvider(.init(enabled: true, path: "https://example.com/feed.json"))?.id == "http")
    for connector in registry.connectors where connector.implicit { #expect(connector.makeProvider(.init()) != nil, Comment(rawValue: connector.id)) }
    #expect(registry.connector("claude-code")?.makeProvider(.init(enabled: true, path: "/tmp/claude"))?.fingerprint == "/tmp/claude")
}

@Test @MainActor func providerAssemblyFollowsTemplateNamespacesAndConnections() throws {
    let templates = try bundledTemplates()
    let claude = try #require(templates.first { $0.id == "claude-current" })
    #expect(!WallpaperProviderAssembly.providers(for: claude, connections: [:]).contains { $0.id == "claude" })
    let connected = WallpaperProviderAssembly.providers(for: claude, connections: ["claude-code": .init(enabled: true, path: "/tmp/claude")])
    #expect(connected.contains { $0.id == "claude" && $0.fingerprint == "/tmp/claude" })
    for provider in connected { #expect(claude.dataNamespaces.contains(provider.id), Comment(rawValue: provider.id)) }
    let github = try #require(templates.first { $0.id == "github-after-hours" })
    #expect(WallpaperProviderAssembly.providers(for: github, connections: ["github-profile": .init(enabled: true, username: "alice")]).contains { $0.id == "github" && $0.fingerprint == "alice" })
    #expect(!WallpaperProviderAssembly.providers(for: github, connections: ["github-profile": .init(enabled: true, username: "not valid")]).contains { $0.id == "github" })
    let countdown = try #require(templates.first { $0.countdown != nil })
    #expect(WallpaperProviderAssembly.providers(for: countdown, connections: [:]).contains { $0.id == "countdown" })
    // A new connector is one descriptor; templates reach it through the namespace they bind.
    let custom = WallpaperConnectorRegistry(connectors: [.init(id: "metrics", title: "Metrics", namespaces: ["mac"], implicit: true, makeProvider: { _ in MacWallpaperProvider() })])
    let pulse = try #require(templates.first { $0.id == "pulse" })
    #expect(WallpaperProviderAssembly.providers(for: pulse, connections: [:], registry: custom).map(\.id) == ["mac"])
    #expect(!WallpaperSetupController.isReady(claude, connections: ["claude-code": .init(enabled: true)], registry: custom), "An unknown required connector is never ready")
}

@Test func playbackPolicyFollowsUserChoicesAndSystemState() {
    var system = SystemState()
    var playback = WallpaperPlaybackPolicy.playback(enabled: true, browsing: false, maximumFPS: 60, system: system)
    #expect(playback.framesPerSecond == 60 && playback.shouldSample)
    system.lowPower = true
    #expect(WallpaperPlaybackPolicy.playback(enabled: true, browsing: false, maximumFPS: 60, system: system).framesPerSecond == 30)
    system.lowPower = false; system.reduceMotion = true
    #expect(WallpaperPlaybackPolicy.playback(enabled: true, browsing: false, maximumFPS: 60, system: system).framesPerSecond == 1)
    system.reduceMotion = false; system.sessionInactive = true
    playback = WallpaperPlaybackPolicy.playback(enabled: true, browsing: true, maximumFPS: 60, system: system)
    #expect(playback.sleeping && playback.framesPerSecond == 0 && !playback.shouldSample, "Another user's session hides the desktop")
    system.sessionInactive = false; system.screensAsleep = true
    #expect(WallpaperPlaybackPolicy.playback(enabled: false, browsing: true, maximumFPS: 30, system: system).sleeping)
    system.screensAsleep = false
    #expect(WallpaperPlaybackPolicy.playback(enabled: false, browsing: true, maximumFPS: 30, system: system).framesPerSecond == 30)
    #expect(!WallpaperPlaybackPolicy.playback(enabled: false, browsing: false, maximumFPS: 60, system: system).shouldSample)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func coverStoreKeysAreStableAndCachedCoversSkipRendering() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let shaders = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: shaders, loadUserTemplates: false)
    var template = try #require(registry.templates.first { $0.id == "pulse" })
    template.id = "cover-test"
    #expect(WallpaperCoverStore.cacheKey(for: template) == WallpaperCoverStore.cacheKey(for: template))
    var editorial = template; editorial.metadata = .init(overview: "New description", authors: [.unfoldMyMac])
    #expect(WallpaperCoverStore.cacheKey(for: editorial) == WallpaperCoverStore.cacheKey(for: template), "Editorial changes do not invalidate rendered covers")
    var edited = template; edited.accent ^= 0xFF
    #expect(WallpaperCoverStore.cacheKey(for: edited) != WallpaperCoverStore.cacheKey(for: template), "Any content change produces a new cover")
    let factory = WallpaperPipelineFactory(gpu: try TestGPU.context(), shaders: shaders)
    let store = WallpaperCoverStore(factory: factory, directory: directory)
    store.request([template, template])
    #expect(store.images.isEmpty && store.rendered == 0, "Nothing is read or rendered before the caller returns")
    try await settle { store.images[template.id] != nil }
    #expect(store.rendered == 1 && FileManager.default.fileExists(atPath: store.cacheURL(for: template).path))
    let warm = WallpaperCoverStore(factory: factory, directory: directory)
    let bundled = try #require(registry.templates.first { registry.assets(for: $0.id).cover(for: $0) != nil })
    warm.request([template, bundled], assets: registry.assets(for:))
    try await settle { warm.images.count == 2 }
    #expect(warm.rendered == 0, "Disk-cached and folder covers never render")
    warm.invalidate(template.id)
    #expect(warm.images[template.id] == nil)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func wallpaperModelStartsWithoutRenderingCoversAndReleasesAfterShutdown() async throws {
    let suite = "wallpaper-runtime-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    weak var released: WallpaperModel?
    do {
        let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(), displays: FakeDisplay(),
                                   surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(), coverDirectory: directory, providerLink: .isolated())
        released = model
        model.start()
        #expect(model.previewPipeline?.template.id == "pulse" && model.activePipeline == nil)
        #expect(model.covers.rendered == 0 && model.thumbnails.isEmpty, "Launch builds only the preview pipeline (P17)")
        model.setBrowsing(true); model.setPreviewVisible(true)
        model.apply()
        #expect(model.enabled && model.desktop.isShowing && model.desktop.windows.count == 1)
        #expect(model.stats == RenderStats(), "Desktop stats start empty and come from the slowest display")
        model.desktop.surface.record(RenderStats(fps: 60), for: 1)
        model.desktop.surface.record(RenderStats(fps: 24), for: 2)
        #expect(model.stats.fps == 24)
        model.shutdown()
        #expect(!model.desktop.isShowing && model.desktop.windows.isEmpty && model.activePipeline == nil)
    }
    try await settle { released == nil }
    #expect(released == nil, "Nothing outlives the model after shutdown (W3)")
}

@Test @MainActor func dataCoordinatorKeepsUnchangedProvidersAndStopsBothHubs() async throws {
    let coordinator = WallpaperDataCoordinator()
    let pulse = try #require(bundledTemplates().first { $0.id == "pulse" })
    coordinator.update(desktop: pulse, preview: pulse, connections: [:], sampling: true)
    try await settle { coordinator.desktop.snapshot.sources["mac"] != nil && coordinator.preview.snapshot.sources["mac"] != nil }
    let stamp = coordinator.desktop.snapshot.sources["mac"]?.timestamp
    coordinator.update(desktop: pulse, preview: nil, connections: [:], sampling: true)
    #expect(coordinator.desktop.snapshot.sources["mac"]?.timestamp == stamp, "An unchanged provider keeps its task and sample")
    #expect(coordinator.preview.snapshot.sources.isEmpty, "A hub with no template stops its providers")
    coordinator.update(desktop: pulse, preview: nil, connections: [:], sampling: false)
    #expect(coordinator.desktop.snapshot.sources.isEmpty)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func wallpaperApplyStopAndPreviewCyclesReleaseEveryPipelineAndWindow() async throws {
    let suite = "wallpaper-cycle-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(), displays: FakeDisplay(),
                               surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(), coverDirectory: directory, providerLink: .isolated())
    model.start(); model.setBrowsing(true); model.setPreviewVisible(true)
    var pipelines: [WeakPipeline] = []
    var controllers: [WeakController] = []
    for _ in 0..<10 {
        model.apply()
        #expect(model.enabled && model.desktop.isShowing)
        pipelines.append(WeakPipeline(model.activePipeline)); controllers.append(contentsOf: model.desktop.controllers.map(WeakController.init))
        model.stopWallpaper()
        #expect(!model.enabled && !model.desktop.isShowing && model.activePipeline == nil)
    }
    let free = ["pulse", "lights-out", "gta-vi-countdown", "aurora-observatory"]
    for index in 0..<20 {
        model.select(free[index % free.count])
        pipelines.append(WeakPipeline(model.previewPipeline))
        #expect(model.previewPipeline?.template.id == free[index % free.count] && model.error == nil)
    }
    model.select("pulse")
    model.shutdown()
    #expect(controllers.allSatisfy { $0.value == nil }, "Every desktop window controller and its display link went with its Stop (P2)")
    let retained = pipelines.filter { $0.value != nil }.count
    #expect(retained == 0, "No pipeline outlives Apply/Stop ×10 and preview switching ×20: \(retained) retained")
}

private final class WeakPipeline { weak var value: WallpaperPipeline?; init(_ value: WallpaperPipeline?) { self.value = value } }
@MainActor private final class WeakController { weak var value: WallpaperDesktopWindowController?; init(_ value: WallpaperDesktopWindowController) { self.value = value } }
