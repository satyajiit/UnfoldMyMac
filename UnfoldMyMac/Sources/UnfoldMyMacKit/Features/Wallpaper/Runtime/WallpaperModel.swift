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
    /// The bridge to the wallpaper provider extension: it feeds the sandboxed renderer live data and
    /// reports whether macOS is showing it. When it is, the app's own desktop windows stand down.
    let providerLink: WallpaperProviderLink
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

    var preferences: WallpaperPreferences { prefs.preferences }
    var data: WallpaperDataHub { feeds.desktop }
    var previewData: WallpaperDataHub { feeds.preview }
    var enabled: Bool { prefs.enabled }
    var previewFPS: Int { browsing && previewVisible ? min(playback.framesPerSecond, selected?.fpsCeiling ?? .max) : 0 }

    init(preferences store: any PreferencesStore, environment: any SystemEnvironmentObserving, displays: any DisplayProviding,
         surfaces: DesktopSurfaceRegistry, gpu: GPUContext?, systemBackdrop: WallpaperSystemBackdrop? = nil,
         connectors: WallpaperConnectorRegistry = .standard, coverDirectory: URL = WallpaperCoverStore.defaultDirectory,
         inputs: WallpaperInputService = WallpaperInputService(),
         providerLink: WallpaperProviderLink = WallpaperProviderLink()) {
        self.inputs = inputs; self.providerLink = providerLink
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
        providerLink.onStatusChanged = { [weak self] _ in self?.providerStatusChanged() }
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
            // Off is not idle: macOS may already be showing our provider, and only this app can feed it.
            // Both branches therefore reconcile the whole picture. A still left behind by a crash is
            // restored once we know the screen is ours; NSWorkspace round trips cost ~100 ms.
            if enabled { apply() } else { Task { [weak self] in self?.rebuildDesktop() } }
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
        // Not `syncSystemBackdrop` alone: the provider may still be the system's wallpaper, and the link
        // has to be told the app's own scene is gone so it keeps feeding the right one.
        refreshPlayback(); rebuildDesktop()
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
    func receiveStats(_ value: RenderStats) { previewStats = value }
    func shutdown() {
        browsing = false; systemState.stop(); desktop.stop(); covers.cancel(); activity.setRendering(false)
        providerLink.stop()
        feeds.reset(); setup.cancel(); inputs.stop()
        do { try systemBackdrop?.restore() } catch { self.error = error.localizedDescription }
        playback = .init(); activePipeline = nil; previewPipeline = nil
    }

    /// The validator the catalog runs an imported template through, or nil without a GPU.
    var pipelineFactory: WallpaperPipelineFactory? { factory }
    /// Drops the preview pipeline. A template that no longer exists must not keep its GPU resources alive.
    func discardPreview() { previewPipeline = nil }

    private func preparePreview() throws {
        guard let selected, let factory else { return }
        let image = WallpaperPipelineFactory.backgroundImage(for: selected, customBackground: preferences.customBackground)
        previewPipeline = try factory.make(selected, imageURL: image, assets: catalog.assets(for: selected.id))
    }
    /// macOS started or stopped showing our provider. That changes who draws the desktop, which scene the
    /// data feed must follow, and whether the app may touch the system wallpaper at all.
    private func providerStatusChanged() {
        refreshPlayback()
        rebuildDesktop()
    }
    /// The scene the data feed must follow.
    ///
    /// While macOS is showing our provider that is the provider's scene, not the app's. The user may have
    /// picked a different one in System Settings, or switched the app's own wallpaper off entirely, and
    /// the readouts on the desktop and the lock screen still have to be the right ones — sampling the
    /// wrong template is exactly how a scene ends up showing dashes where its numbers belong.
    private var dataTemplate: WallpaperTemplate? {
        // A stalled provider is still the system's wallpaper — frozen, but ours — so its scene is still
        // the one to sample. Dropping it here hands the wrong numbers to the surface on screen.
        switch providerLink.status {
        case .live(let id, _), .stalled(let id): return id.flatMap(catalog.template) ?? activePipeline?.template
        case .idle, .unknown, .failed: return enabled ? activePipeline?.template : nil
        }
    }
    private func rebuildDesktop() {
        // Feeding the provider is the app's job whenever macOS is showing it, whatever the app's own
        // wallpaper toggle says: nothing else can read ~/.claude, the lid angle or the microphone.
        providerLink.update(enabled: enabled || providerLink.status.isLive,
                            templateID: enabled ? preferences.templateID : nil, source: feeds.desktop)
        syncSystemBackdrop()
        guard enabled, let activePipeline else { return }
        // macOS is compositing the scene itself, on the desktop and the lock screen. Putting our own
        // windows up as well would render every frame twice for the same picture.
        guard !providerLink.status.isLive else { desktop.stop(); return }
        desktop.show(pipeline: activePipeline, source: feeds.desktop, framesPerSecond: playback.framesPerSecond, styleSheet: catalog.style)
    }
    /// Colours the system wallpaper sampler behind our own desktop windows.
    ///
    /// This writes the user's system wallpaper, so it runs only once we know macOS is not already showing
    /// our provider — otherwise applying a still here would silently replace the user's choice of our own
    /// extension with a picture of it, and take the lock screen with it.
    private func syncSystemBackdrop() {
        guard providerLink.status.allowsSystemWallpaperChanges else { return }
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
        feeds.update(desktop: dataTemplate, preview: browsing && previewVisible && !isSelectedApplied ? selected : nil,
                     connections: setup.connections, sampling: next.shouldSample || (providerLink.status.isLive && !next.sleeping))
    }
}
