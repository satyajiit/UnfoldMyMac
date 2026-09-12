import UnfoldMyMacCore

/// Composition root of the lid-effects feature.
@MainActor enum EffectsFeature {
    /// How long a slider may keep moving before its value is written.
    static let persistenceDelay: Duration = .milliseconds(250)
    static func make(dependencies: AppDependencies) -> EffectsModel {
        let registry = EffectRegistry.builtIn()
        AppSupportPaths.migrateLegacyArtwork()
        let library = ArtworkLibrary()
        for artwork in library.definitions { try? registry.register(.artwork(artwork)) }
        let surfaces = dependencies.surfaces
        let session = EffectSession(registry: registry, host: EffectHost(), displays: dependencies.displays, gpu: dependencies.gpu, makeCapture: { DesktopCapture(surfaces: surfaces) })
        return EffectsModel(dependencies: EffectsDependencies(
            preferences: dependencies.preferences, registry: registry, makeSensor: { LidSensor() }, displays: dependencies.displays,
            session: session, environment: dependencies.environment, filePicker: dependencies.filePicker, workspace: dependencies.workspace,
            capturePermission: dependencies.capturePermission, artworkLibrary: library, clock: dependencies.clock,
            persistence: PersistenceScheduler(delay: EffectsFeature.persistenceDelay)))
    }
}
