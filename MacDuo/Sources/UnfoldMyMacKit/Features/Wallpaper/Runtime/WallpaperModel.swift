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
    private(set) var stats = WallpaperRenderStats()
    private var previewVisible = false
    var error: String?
    let data = WallpaperDataHub()
    let previewData = WallpaperDataHub()
    let setup: WallpaperSetupController
    var previewSnapshot: WallpaperSnapshot { isSelectedApplied ? data.snapshot : previewData.snapshot }
    @ObservationIgnored private let host = WallpaperDesktopHost()
    @ObservationIgnored private let environment = WallpaperEnvironment()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let systemBackdrop: WallpaperSystemBackdrop?
    @ObservationIgnored private var registry: WallpaperTemplateRegistry?
    @ObservationIgnored private var sampling = false
    @ObservationIgnored private var browsing = false
    var selected: WallpaperTemplate? { templates.first { $0.id == selectedID } }
    var enabled: Bool { preferences.enabled }
    var desktopWindowIDs: Set<CGWindowID> { Set(host.windows.compactMap { CGWindowID(exactly: $0.windowNumber) }) }
    var previewFPS: Int { browsing && previewVisible ? playback.framesPerSecond : 0 }
    var activeTitle: String { templates.first { $0.id == preferences.templateID }?.title ?? "Wallpaper" }
    var isSelectedApplied: Bool { enabled && preferences.templateID == selectedID }

    init(defaults: UserDefaults = .standard, systemBackdrop: WallpaperSystemBackdrop? = nil) {
        self.defaults = defaults
        self.systemBackdrop = systemBackdrop
        let saved = WallpaperPreferences.load(from: defaults)
        preferences = saved; selectedID = saved.templateID
        setup = WallpaperSetupController(defaults: defaults)
        setup.onChange = { [weak self] in self?.connectionsChanged() }
        setup.onApply = { [weak self] id in self?.select(id); self?.apply() }
    }
    func start() {
        do {
            let shaders = try WallpaperShaderCatalog()
            let registry = try WallpaperTemplateRegistry(shaders: shaders)
            self.registry = registry; templates = registry.templates
            for template in templates {
                let pipeline = try WallpaperPipeline(template: template, catalog: shaders)
                thumbnails[template.id] = try WallpaperThumbnailRenderer.cover(pipeline: pipeline)
            }
            if selected == nil { selectedID = templates.first?.id ?? "pulse" }
            try preparePreview()
            if !registry.errors.isEmpty { error = registry.errors.joined(separator: "\n") }
            environment.onChange = { [weak self] in self?.refreshPlayback() }
            environment.onDisplaysChanged = { [weak self] in self?.rebuildDesktop() }
            environment.onSpaceChanged = { [weak self] in self?.syncSystemBackdrop() }
            environment.start()
            if preferences.enabled, let selected, !setup.isReady(selected) {
                preferences.enabled = false; preferences.save(to: defaults)
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
        preferences.save(to: defaults); refreshPlayback(); rebuildDesktop()
    }
    func stopWallpaper() {
        preferences.enabled = false; preferences.save(to: defaults)
        host.stop(); activePipeline = nil; stats = .init(); refreshPlayback()
        syncSystemBackdrop()
    }
    func setBrowsing(_ value: Bool) { browsing = value; refreshPlayback() }
    func setPreviewVisible(_ value: Bool) {
        previewVisible = value
        if !value && !enabled { stats = .init() }
    }
    func setMaximumFPS(_ fps: Int) { preferences.maximumFPS = fps == 30 ? 30 : 60; preferences.save(to: defaults); refreshPlayback() }
    func setCustomBackground(_ enabled: Bool) {
        preferences.customBackground = enabled; preferences.save(to: defaults)
        select(selectedID)
        if isSelectedApplied { apply() }
    }
    func importTemplate(_ url: URL) {
        do {
            guard let registry else { return }
            let template = try registry.importTemplate(url)
            templates = registry.templates
            let pipeline = try WallpaperPipeline(template: template, catalog: registry.shaders)
            thumbnails[template.id] = try WallpaperThumbnailRenderer.cover(pipeline: pipeline)
            select(template.id)
        } catch { self.error = error.localizedDescription }
    }
    func receiveStats(_ value: WallpaperRenderStats) { stats = value }
    func shutdown() {
        browsing = false; host.stop(); environment.stop(); data.stop(); previewData.stop(); setup.cancel(); sampling = false
        do { try systemBackdrop?.restore() } catch { self.error = error.localizedDescription }
        playback = .init(); activePipeline = nil; previewPipeline = nil
    }
    private func preparePreview() throws {
        guard let selected, let registry else { return }
        let image = preferences.customBackground && selected.image != nil && selected.allowsCustomBackground != false ? WallpaperPaths.background : nil
        previewPipeline = try WallpaperPipeline(template: selected, catalog: registry.shaders, imageURL: image)
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
        preferences.save(to: defaults)
        data.stop(); previewData.stop(); sampling = false
        if let active = activePipeline?.template, enabled, !setup.isReady(active) { stopWallpaper() }
        refreshPlayback()
    }
    private func refreshPlayback() {
        var next = WallpaperPlayback()
        next.enabled = enabled; next.preview = browsing; next.sleeping = environment.suspended
        next.reducedMotion = environment.reducedMotion; next.lowPower = environment.lowPower
        next.thermallyLimited = environment.thermal; next.maximumFPS = preferences.maximumFPS
        playback = next
        environment.setRendering(next.enabled && !next.sleeping && next.animates)
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
