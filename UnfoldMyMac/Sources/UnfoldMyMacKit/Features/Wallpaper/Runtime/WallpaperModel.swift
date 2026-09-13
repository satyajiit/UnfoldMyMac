import AppKit
import Observation
import UnfoldMyMacCore

/// The wallpaper feature's façade: the state its views read and the commands they send. Loading, covers,
/// playback, data, desktop windows and preferences each live in a collaborator; this type sequences them.
@MainActor @Observable final class WallpaperModel {
    let catalog: WallpaperCatalog
    let covers: WallpaperCoverStore
    let setup: WallpaperSetupController
    let desktop: WallpaperDesktopCoordinator
    let inputs: WallpaperInputService
    private(set) var selectedID: String
    private(set) var previewPipeline: WallpaperPipeline?
    private(set) var activePipeline: WallpaperPipeline?
    private(set) var playback = WallpaperPlayback()
    private(set) var previewStats = RenderStats()
    var error: String?
    @ObservationIgnored private let prefs: WallpaperPreferencesController
    @ObservationIgnored private let feeds: WallpaperDataCoordinator
    @ObservationIgnored private let factory: WallpaperPipelineFactory?
    @ObservationIgnored private let environment: any SystemEnvironmentObserving
    @ObservationIgnored private let systemState: SystemStateSubscriber
    @ObservationIgnored private let activity = RenderingActivity()
    @ObservationIgnored private let systemBackdrop: WallpaperSystemBackdrop?
    @ObservationIgnored private var browsing = false
    @ObservationIgnored private var previewVisible = false

    var templates: [WallpaperTemplate] { catalog.templates }
    var thumbnails: [String: NSImage] { covers.images }
    var preferences: WallpaperPreferences { prefs.preferences }
    var data: WallpaperDataHub { feeds.desktop }
    var previewData: WallpaperDataHub { feeds.preview }
    var selected: WallpaperTemplate? { catalog.template(selectedID) }
    var enabled: Bool { prefs.enabled }
    var previewFPS: Int { browsing && previewVisible ? min(playback.framesPerSecond, selected?.fpsCeiling ?? .max) : 0 }
    var activeTitle: String { catalog.template(preferences.templateID)?.title ?? "Wallpaper" }
    var isSelectedApplied: Bool { enabled && preferences.templateID == selectedID }
    var previewSnapshot: WallpaperSnapshot { isSelectedApplied ? data.snapshot : previewData.snapshot }
    /// The slowest desktop display while applied; the preview card's own surface otherwise.
    var stats: RenderStats { enabled ? desktop.surface.worstStats : previewStats }

    init(preferences store: any PreferencesStore, environment: any SystemEnvironmentObserving, displays: any DisplayProviding,
         surfaces: DesktopSurfaceRegistry, gpu: GPUContext?, systemBackdrop: WallpaperSystemBackdrop? = nil,
         connectors: WallpaperConnectorRegistry = .standard, coverDirectory: URL = WallpaperCoverStore.defaultDirectory,
         inputs: WallpaperInputService = WallpaperInputService()) {
        self.inputs = inputs
        let shaders = WallpaperShaderCatalog()
        let factory = gpu.map { WallpaperPipelineFactory(gpu: $0, shaders: shaders) }
        let prefs = WallpaperPreferencesController(store: store)
        self.environment = environment; self.systemBackdrop = systemBackdrop; self.factory = factory; self.prefs = prefs
        selectedID = prefs.preferences.templateID
        catalog = WallpaperCatalog(shaders: shaders, connectors: connectors)
        covers = WallpaperCoverStore(factory: factory, directory: coverDirectory)
        setup = WallpaperSetupController(preferences: store, registry: connectors, inputs: inputs)
        feeds = WallpaperDataCoordinator(registry: connectors)
        desktop = WallpaperDesktopCoordinator(surfaces: surfaces, displays: displays, inputs: inputs)
        systemState = SystemStateSubscriber(environment: environment)
        setup.onChange = { [weak self] in self?.connectionsChanged() }
        setup.onApply = { [weak self] id in self?.select(id); self?.apply() }
    }
    /// Loads the collection and builds the preview pipeline only; covers arrive afterwards (P17).
    func start() {
        do {
            guard factory != nil else { throw GPUError.metalUnavailable }
            try catalog.load()
            if selected == nil { selectedID = templates.first?.id ?? WallpaperPreferences().templateID }
            covers.request(templates, assets: catalog.assets(for:))
            try preparePreview()
            if !catalog.errors.isEmpty { error = catalog.errors.joined(separator: "\n") }
            if enabled, let selected, !setup.isReady(selected) { prefs.disable() }
            // Off: a still left behind by a crash is restored once the window is up; NSWorkspace round trips cost ~100 ms.
            if enabled { apply() } else { Task { [weak self] in self?.syncSystemBackdrop() } }
            systemState.start { [weak self] event in self?.systemChanged(event) }
        } catch { self.error = error.localizedDescription; prefs.disable(save: false) }
    }
    func select(_ id: String) {
        guard catalog.template(id) != nil else { return }
        selectedID = id
        feeds.resetPreview()
        do { try preparePreview(); error = nil }
        catch { self.error = error.localizedDescription; previewPipeline = nil }
        refreshPlayback()
    }
    func apply() {
        guard let previewPipeline else { return }
        guard setup.isReady(previewPipeline.template) else { setup.open(previewPipeline.template, applyAfterSetup: true); return }
        if activePipeline?.template.id != previewPipeline.template.id { feeds.resetDesktop() }
        activePipeline = previewPipeline
        prefs.enable(templateID: selectedID)
        refreshPlayback(); rebuildDesktop()
    }
    func stopWallpaper() {
        prefs.disable(); desktop.stop(); activePipeline = nil
        refreshPlayback(); syncSystemBackdrop()
    }
    func setBrowsing(_ value: Bool) { browsing = value; refreshPlayback() }
    func setPreviewVisible(_ value: Bool) {
        previewVisible = value
        refreshPlayback()
        if !value { previewStats = .init() }
    }
    func setMaximumFPS(_ fps: Int) { prefs.setMaximumFPS(fps); refreshPlayback() }
    func setCustomBackground(_ value: Bool) {
        prefs.setCustomBackground(value)
        select(selectedID)
        if isSelectedApplied { apply() }
    }
    /// Copies `url` in as the shared custom background and switches image-based scenes to it.
    func importBackground(_ url: URL) {
        Task { [weak self] in
            do { try await WallpaperBackgroundImporter.save(url); self?.setCustomBackground(true) }
            catch { self?.error = error.localizedDescription }
        }
    }
    func importTemplate(_ url: URL) {
        do {
            guard let factory else { return }
            let template = try catalog.importTemplate(url) { try factory.validate($0) }
            covers.invalidate(template.id); covers.request([template])
            select(template.id)
        } catch { self.error = error.localizedDescription }
    }
    func renameTemplate(_ id: String, title: String) {
        do {
            try catalog.rename(id, title: title)
            guard let template = catalog.template(id) else { return }
            covers.invalidate(id); covers.request([template])
            if selectedID == id { select(id) }
        } catch { self.error = error.localizedDescription }
    }
    /// Removes an imported template; a desktop showing it stops first and the preview moves to the first scene.
    func removeTemplate(_ id: String) {
        do {
            if enabled, preferences.templateID == id { stopWallpaper() }
            try catalog.remove(id); covers.invalidate(id)
            if selectedID == id { previewPipeline = nil; if let first = templates.first?.id { select(first) } }
        } catch { self.error = error.localizedDescription }
    }
    func receiveStats(_ value: RenderStats) { previewStats = value }
    func shutdown() {
        browsing = false; systemState.stop(); desktop.stop(); covers.cancel(); activity.setRendering(false)
        feeds.reset(); setup.cancel(); inputs.stop()
        do { try systemBackdrop?.restore() } catch { self.error = error.localizedDescription }
        playback = .init(); activePipeline = nil; previewPipeline = nil
    }

    private func preparePreview() throws {
        guard let selected, let factory else { return }
        let image = WallpaperPipelineFactory.backgroundImage(for: selected, customBackground: preferences.customBackground)
        previewPipeline = try factory.make(selected, imageURL: image, assets: catalog.assets(for: selected.id))
    }
    private func rebuildDesktop() {
        syncSystemBackdrop()
        guard enabled, let activePipeline else { return }
        desktop.show(pipeline: activePipeline, source: feeds.desktop, framesPerSecond: playback.framesPerSecond, styleSheet: catalog.style)
    }
    private func syncSystemBackdrop() {
        do {
            if enabled, let activePipeline { try systemBackdrop?.apply(activePipeline) }
            else { try systemBackdrop?.restore() }
        } catch { self.error = "System wallpaper background: " + error.localizedDescription }
    }
    private func connectionsChanged() {
        feeds.reset()
        if let active = activePipeline?.template, enabled, !setup.isReady(active) { stopWallpaper() }
        refreshPlayback()
    }
    private func systemChanged(_ event: SystemStateSubscriber.Event) {
        refreshPlayback()
        switch event {
        case .displaysChanged: rebuildDesktop()
        case .spaceChanged: syncSystemBackdrop()
        case .sleep, .wake, .accessibility: break
        }
    }
    private func refreshPlayback() {
        let next = WallpaperPlaybackPolicy.playback(enabled: enabled, browsing: browsing, maximumFPS: preferences.maximumFPS, system: environment.state)
        if next != playback { playback = next }
        inputs.configure(connections: setup.effectiveConnections, suspended: next.sleeping, reducedMotion: next.reducedMotion)
        activity.setRendering(next.enabled && !next.sleeping && next.animates)
        desktop.setFramesPerSecond(min(next.framesPerSecond, activePipeline?.template.fpsCeiling ?? .max))
        feeds.update(desktop: enabled ? activePipeline?.template : nil, preview: browsing && previewVisible && !isSelectedApplied ? selected : nil,
                     connections: setup.connections, sampling: next.shouldSample)
    }
}
