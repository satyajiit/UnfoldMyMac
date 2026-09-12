import Foundation
import Observation
import UnfoldMyMacCore

/// The lid-effects feature as the window, menu bar and tests see it: one command surface composed from the
/// runtime (sensor, display gate, session, clocks), the persisted preferences, the library's browse state,
/// artwork import and the Screen Recording permission state. It routes; it does not compute.
@MainActor @Observable final class EffectsModel {
    let registry: EffectRegistry
    let preferences: EffectPreferences
    let library: EffectLibraryViewModel
    let permissions: PermissionsController
    @ObservationIgnored let artworkLibrary: ArtworkLibrary?
    /// The app shell, when one is attached; previews started elsewhere bring the library forward through it.
    @ObservationIgnored weak var navigator: (any EffectsNavigating)?
    /// Internal for the composition root and tests; views go through the model.
    @ObservationIgnored let runtime: EffectRuntime
    @ObservationIgnored private let importer: ArtworkImportController

    init(dependencies: EffectsDependencies) {
        let registry = dependencies.registry, artworkLibrary = dependencies.artworkLibrary
        self.registry = registry; self.artworkLibrary = artworkLibrary
        preferences = EffectPreferences(store: dependencies.preferences, registry: registry, artworkLoadFailed: artworkLibrary?.loadError != nil, scheduler: dependencies.persistence)
        library = EffectLibraryViewModel(message: artworkLibrary?.loadError ?? registry.catalogError)
        permissions = PermissionsController(capturePermission: dependencies.capturePermission, workspace: dependencies.workspace)
        importer = ArtworkImportController(library: artworkLibrary, registry: registry, filePicker: dependencies.filePicker)
        runtime = EffectRuntime(session: dependencies.session, registry: registry, preferences: preferences, environment: dependencies.environment,
                                displays: dependencies.displays, makeSensor: dependencies.makeSensor, clock: dependencies.clock)
        dependencies.session.onError = { [weak self] error in self?.failed(error) }
    }

    // MARK: State

    var settings: UnfoldMyMacSettings { preferences.settings }
    var parameters: EffectParameters { preferences.parameters }
    var completionAngle: Double { preferences.completionAngle }
    var selectedEffect: EffectDescriptor { registry.entry(for: settings.effect).descriptor }
    /// Trying an effect never overwrites the user's chosen design or its parameters.
    var activeEffect: EffectDescriptor { runtime.activeEffect }
    var needsCapture: Bool { activeEffect.requiresCapture && !reduceTransparency }
    var enabled: Bool { runtime.enabled }
    var status: String { EffectStatusFormatter.label(for: runtime.status, registry: registry) }
    var lidAngle: Double? { runtime.lidAngle }
    var angleLabel: String { lidAngle.map { "\(Int($0.rounded()))°" } ?? "—" }
    var sensorAvailable: Bool { runtime.sensorAvailable }
    var diagnostic: String { runtime.diagnostic }
    var displayName: String { runtime.displayName }
    var captureFrames: Int { runtime.captureFrames }
    var gpuMilliseconds: Double { runtime.gpuMilliseconds }
    var reduceTransparency: Bool { runtime.reduceTransparency }
    var reduceMotion: Bool { runtime.reduceMotion }
    var isPreviewing: Bool { runtime.isPreviewing }
    var isPlaying: Bool { runtime.isPlaying }
    var previewEffectID: EffectID? { runtime.previewEffectID }
    var previewClosure: Double { runtime.previewClosure }
    var effectProgress: Double { EffectMath.calibratedClosure(previewClosure, completionFraction: settings.completionFraction) }
    var errorMessage: String? { permissions.errorMessage }
    var needsPermission: Bool { permissions.needsPermission }
    var isImporting: Bool { importer.isImporting }
    var libraryCategory: EffectCategory? { get { library.category } set { library.category = newValue } }
    var libraryQuery: String { get { library.query } set { library.query = newValue } }
    var libraryTag: String? { get { library.tag } set { library.tag = newValue } }
    var libraryMessage: String? { get { library.message } set { library.message = newValue } }

    // MARK: Lifecycle

    func start() { runtime.start() }
    func shutdown() { runtime.shutdown(); preferences.flush() }
    func tick() { runtime.tick() }
    func renderFrame(deltaTime: TimeInterval) { runtime.renderFrame(deltaTime: deltaTime) }
    func setWindowVisible(_ visible: Bool) { runtime.setAngleObserved(visible) }

    // MARK: Commands

    func setEnabled(_ value: Bool) { permissions.clear(); runtime.setEnabled(value) }
    func selectEffect(_ id: EffectID) {
        if isPreviewing { stopPreview() }
        guard preferences.select(registry.entry(for: id).descriptor.id) else { return }
        permissions.clear(); runtime.effectChanged()
    }
    func setStrength(_ strength: Double) { preferences.setStrength(strength) }
    func setReveal(_ reveal: ArtRevealMotion) { preferences.setReveal(reveal) }
    func setActivation(_ angle: Double) { preferences.setActivation(angle); runtime.tick() }
    func setCompletionFraction(_ fraction: Double) { preferences.setCompletionFraction(fraction) }
    func anchorHere() { if sensorAvailable, let lidAngle { setActivation(lidAngle) } }
    func setAppearance(_ appearance: AppearancePreference) { preferences.setAppearance(appearance) }
    func setShowAngle(_ value: Bool) { preferences.setShowAngle(value); runtime.refreshPolling() }
    func openScreenRecordingSettings() { permissions.openScreenRecordingSettings() }

    func togglePreview(for id: EffectID) {
        if isPreviewing && previewEffectID == id { stopPreview(); return }
        beginPreview(effect: id)
        if !reduceMotion { runtime.playPreview() }
    }
    func beginPreview(effect id: EffectID? = nil) {
        permissions.clear()
        if runtime.beginPreview(effect: id) { navigator?.showEffectsLibrary() }
    }
    func playPreview() { runtime.playPreview() }
    func pausePreview() { runtime.pausePreview() }
    func scrubPreview(_ value: Double) { runtime.scrubPreview(value) }
    func stopPreview() { runtime.stopPreview() }

    // MARK: Artwork

    func chooseArtwork() {
        guard !importer.isImporting, importer.isAvailable else { return }
        Task { [weak self] in
            guard let self, let url = await importer.pickImage() else { return }
            await importArtwork(at: url)
        }
    }
    func importArtwork(at url: URL) async {
        library.message = nil
        do {
            guard let id = try await importer.importImage(at: url) else { return }
            library.showImported(); selectEffect(id)
        } catch { library.message = error.localizedDescription }
    }
    func updateArtworkCredits(title: String, author: String) {
        do { try importer.updateCredits(of: settings.effect, title: title, author: author); library.message = nil }
        catch { library.message = error.localizedDescription }
    }
    @discardableResult func removeArtwork(_ id: EffectID) -> Bool {
        do {
            guard try importer.removeFromLibrary(id) else { return false }
            if previewEffectID == id { stopPreview() }
            if settings.effect == id { selectEffect(.reverie) }
            registry.removeImported(id); preferences.removeParameters(for: id)
            library.message = nil
            return true
        } catch { library.message = error.localizedDescription; return false }
    }

    private func failed(_ error: Error) {
        let needsPermission = permissions.report(error, requestedCapture: needsCapture)
        runtime.effectFailed(needsPermission: needsPermission)
    }
}
