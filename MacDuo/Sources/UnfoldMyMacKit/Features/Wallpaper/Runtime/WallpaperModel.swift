import AppKit
import Observation
import UnfoldMyMacCore

@MainActor @Observable final class WallpaperModel {
    private(set) var preferences: WallpaperPreferences
    private(set) var templates: [WallpaperTemplate] = []
    private(set) var selectedID: String
    private(set) var previewPipeline: WallpaperPipeline?
    private(set) var activePipeline: WallpaperPipeline?
    private(set) var thumbnails: [String: NSImage] = [:]
    private(set) var playback = WallpaperPlayback()
    private(set) var stats = RenderStats()
    private var previewVisible = false
    var error: String?
    let data = WallpaperDataHub()
    let previewData = WallpaperDataHub()
    let setup: WallpaperSetupController
    var previewSnapshot: WallpaperSnapshot { isSelectedApplied ? data.snapshot : previewData.snapshot }
    @ObservationIgnored private let host: WallpaperDesktopHost
    @ObservationIgnored private let environment: any SystemEnvironmentObserving
    @ObservationIgnored private let activity = RenderingActivity()
    @ObservationIgnored private var environmentObservation: Task<Void, Never>?
    @ObservationIgnored private var lastSystemState: SystemState?
    @ObservationIgnored private let preferencesStore: any PreferencesStore
    @ObservationIgnored private let systemBackdrop: WallpaperSystemBackdrop?
    @ObservationIgnored private let gpu: GPUContext?
    @ObservationIgnored private let shaders = WallpaperShaderCatalog()
    @ObservationIgnored private var registry: WallpaperTemplateRegistry?
    @ObservationIgnored private var sampling = false
    @ObservationIgnored private var browsing = false
    var selected: WallpaperTemplate? { templates.first { $0.id == selectedID } }
    var enabled: Bool { preferences.enabled }
    var previewFPS: Int { browsing && previewVisible ? playback.framesPerSecond : 0 }
    var activeTitle: String { templates.first { $0.id == preferences.templateID }?.title ?? "Wallpaper" }
    var isSelectedApplied: Bool { enabled && preferences.templateID == selectedID }

    init(preferences store: any PreferencesStore, environment: any SystemEnvironmentObserving, surfaces: DesktopSurfaceRegistry, gpu: GPUContext?,
         systemBackdrop: WallpaperSystemBackdrop? = nil) {
        preferencesStore = store; self.environment = environment; host = WallpaperDesktopHost(surfaces: surfaces)
        self.systemBackdrop = systemBackdrop; self.gpu = gpu
        let saved = store.load(WallpaperPreferences.key)
        preferences = saved; selectedID = saved.templateID
        setup = WallpaperSetupController(preferences: store)
        setup.onChange = { [weak self] in self?.connectionsChanged() }
        setup.onApply = { [weak self] id in self?.select(id); self?.apply() }
    }
    func start() {
        do {
            guard let gpu else { throw GPUError.metalUnavailable }
            let registry = try WallpaperTemplateRegistry(shaders: shaders)
            self.registry = registry; templates = registry.templates
            for template in templates {
                let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: shaders)
                thumbnails[template.id] = try WallpaperCoverRenderer.cover(pipeline: pipeline)
            }
            if selected == nil { selectedID = templates.first?.id ?? "pulse" }
            try preparePreview()
            if !registry.errors.isEmpty { error = registry.errors.joined(separator: "\n") }
            lastSystemState = environment.state
            let environment = self.environment
            environmentObservation = Task { [weak self] in
                for await state in Observations({ environment.state }) { self?.systemStateChanged(state) }
            }
            if preferences.enabled, let selected, !setup.isReady(selected) {
                preferences.enabled = false; preferencesStore.save(preferences, for: WallpaperPreferences.key)
            }
            if preferences.enabled { apply() }
            else { syncSystemBackdrop() }
            refreshPlayback()
        } catch { self.error = error.localizedDescription; preferences.enabled = false }
    }
    func select(_ id: String) {
        guard templates.contains(where: { $0.id == id }) else { return }
        selectedID = id
        previewData.stop()
        do { try preparePreview(); error = nil }
        catch { self.error = error.localizedDescription; previewPipeline = nil }
        refreshPlayback()
    }
    func apply() {
        guard let previewPipeline else { return }
        guard setup.isReady(previewPipeline.template) else {
            setup.open(previewPipeline.template, applyAfterSetup: true)
            return
        }
        if activePipeline?.template.id != previewPipeline.template.id { data.stop() }
        activePipeline = previewPipeline
        preferences.templateID = selectedID; preferences.enabled = true
        preferencesStore.save(preferences, for: WallpaperPreferences.key); refreshPlayback(); rebuildDesktop()
    }
    func stopWallpaper() {
        preferences.enabled = false; preferencesStore.save(preferences, for: WallpaperPreferences.key)
        host.stop(); activePipeline = nil; stats = .init(); refreshPlayback()
        syncSystemBackdrop()
    }
    func setBrowsing(_ value: Bool) { browsing = value; refreshPlayback() }
    func setPreviewVisible(_ value: Bool) {
        previewVisible = value
        if !value && !enabled { stats = .init() }
    }
    func setMaximumFPS(_ fps: Int) { preferences.maximumFPS = fps == 30 ? 30 : 60; preferencesStore.save(preferences, for: WallpaperPreferences.key); refreshPlayback() }
    func setCustomBackground(_ enabled: Bool) {
        preferences.customBackground = enabled; preferencesStore.save(preferences, for: WallpaperPreferences.key)
        select(selectedID)
        if isSelectedApplied { apply() }
    }
    func importTemplate(_ url: URL) {
        do {
            guard let registry, let gpu else { return }
            let template = try registry.importTemplate(url) { _ = try WallpaperPipeline(template: $0, gpu: gpu, shaders: shaders) }
            templates = registry.templates
            let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: shaders)
            thumbnails[template.id] = try WallpaperCoverRenderer.cover(pipeline: pipeline)
            select(template.id)
        } catch { self.error = error.localizedDescription }
    }
    func receiveStats(_ value: RenderStats) { stats = value }
    func shutdown() {
        browsing = false; host.stop(); environmentObservation?.cancel(); environmentObservation = nil; activity.setRendering(false)
        data.stop(); previewData.stop(); setup.cancel(); sampling = false
        do { try systemBackdrop?.restore() } catch { self.error = error.localizedDescription }
        playback = .init(); activePipeline = nil; previewPipeline = nil
    }
    private func preparePreview() throws {
        guard let selected, registry != nil, let gpu else { return }
        let image = preferences.customBackground && selected.image != nil && selected.allowsCustomBackground != false ? WallpaperPaths.background : nil
        previewPipeline = try WallpaperPipeline(template: selected, gpu: gpu, shaders: shaders, imageURL: image)
    }
    private func rebuildDesktop() {
        syncSystemBackdrop()
        guard enabled, activePipeline != nil else { return }
        host.show { WallpaperDesktopSurface(model: self) }
    }
    private func syncSystemBackdrop() {
        do {
            if enabled, let activePipeline { try systemBackdrop?.apply(activePipeline) }
            else { try systemBackdrop?.restore() }
        } catch { self.error = "System wallpaper background: " + error.localizedDescription }
    }
    private func connectionsChanged() {
        preferencesStore.save(preferences, for: WallpaperPreferences.key)
        data.stop(); previewData.stop(); sampling = false
        if let active = activePipeline?.template, enabled, !setup.isReady(active) { stopWallpaper() }
        refreshPlayback()
    }
    private func systemStateChanged(_ state: SystemState) {
        let previous = lastSystemState; lastSystemState = state
        refreshPlayback()
        if let previous, state.displayGeneration != previous.displayGeneration { rebuildDesktop() }
        if let previous, state.spaceGeneration != previous.spaceGeneration { syncSystemBackdrop() }
    }
    private func refreshPlayback() {
        let system = environment.state
        var next = WallpaperPlayback()
        // The desktop cannot be seen while the machine or its screens sleep or another user's session is active.
        next.enabled = enabled; next.preview = browsing; next.sleeping = system.displaysUnavailable || system.sessionInactive
        next.reducedMotion = system.reduceMotion; next.lowPower = system.lowPower
        next.thermallyLimited = system.thermallyLimited; next.maximumFPS = preferences.maximumFPS
        playback = next
        activity.setRendering(next.enabled && !next.sleeping && next.animates)
        if next.shouldSample {
            data.update(enabled ? providers(for: activePipeline?.template) : [])
            previewData.update(browsing && !isSelectedApplied ? providers(for: selected) : [])
            sampling = true
        }
        if !next.shouldSample && sampling { data.stop(); previewData.stop(); sampling = false }
    }
    private func providers(for template: WallpaperTemplate?) -> [any WallpaperDataProvider] {
        guard let template else { return [] }
        let needed = template.dataNamespaces
        let github = setup.configuration(.githubProfile, for: template.id)
        let activity = setup.configuration(.codexActivity, for: template.id)
        let codex = setup.configuration(.codexHistory, for: template.id)
        let claude = setup.configuration(.claudeCode, for: template.id)
        let tool = setup.configuration(.toolFile, for: template.id)
        var providers: [any WallpaperDataProvider] = []
        if let countdown = template.countdown { providers.append(CountdownWallpaperProvider(countdown: countdown)) }
        if needed.contains("aurora") { providers.append(AuroraWallpaperProvider()) }
        if needed.contains("mac") { providers.append(MacWallpaperProvider()) }
        if needed.contains("scene") { providers.append(WallpaperSessionProvider()) }
        if needed.contains("activity"), activity.enabled { providers.append(CodexActivityProvider()) }
        if needed.contains("github"), github.enabled, let username = github.username { providers.append(GitHubWallpaperProvider(username: username)) }
        if needed.contains("codex"), codex.enabled { providers.append(CodexWallpaperProvider()) }
        if needed.contains("claude"), claude.enabled { providers.append(ClaudeWallpaperProvider(root: URL(fileURLWithPath: claude.path ?? WallpaperPaths.defaultClaudeRoot.path))) }
        if needed.contains("tool"), tool.enabled, let path = tool.path { providers.append(WallpaperJSONProvider(url: URL(fileURLWithPath: path))) }
        return providers
    }
}
