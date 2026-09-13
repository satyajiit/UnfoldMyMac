import Observation
import UnfoldMyMacCore

/// The persisted effect settings and every mutation of them. Continuous sliders persist through the scheduler;
/// discrete choices persist at once. Values update in memory immediately either way.
@MainActor @Observable final class EffectPreferences {
    private(set) var settings: UnfoldMyMacSettings
    @ObservationIgnored private let store: any PreferencesStore
    @ObservationIgnored private let scheduler: PersistenceScheduler
    /// Set when the saved effect is not installed and the registry's fallback stands in for it.
    private(set) var substitutionNotice: String?

    /// Loads the settings, resolves an unknown chosen effect and drops parameters for effects that no longer exist,
    /// unless the artwork index failed to load and their owners may come back once it is repaired.
    init(store: any PreferencesStore, registry: EffectRegistry, artworkLoadFailed: Bool, scheduler: PersistenceScheduler) {
        self.store = store; self.scheduler = scheduler
        var loaded = store.load(UnfoldMyMacSettings.key)
        let resolved = registry.resolve(loaded.effect)
        if resolved.substituted {
            substitutionNotice = "‘\(loaded.effect.rawValue)’ is not installed. \(resolved.entry.descriptor.title) is selected instead."
            loaded.effect = resolved.entry.descriptor.id
        }
        if !artworkLoadFailed, loaded.reconcile(effects: registry.descriptors.map(\.id)) { store.save(loaded, for: UnfoldMyMacSettings.key) }
        settings = loaded
    }
    var parameters: EffectParameters { settings.parameters(for: settings.effect) }
    var completionAngle: Double { EffectMath.completionAngle(activation: settings.activation, completionFraction: settings.completionFraction) }

    /// Returns whether the chosen effect changed.
    @discardableResult func select(_ id: EffectID) -> Bool {
        guard id != settings.effect else { return false }
        settings.effect = id; save()
        return true
    }
    func setStrength(_ strength: Double) {
        var next = parameters
        next.strength = strength.isFinite ? min(1, max(0, strength)) : 1
        settings.parameters[settings.effect.rawValue] = next; saveLater()
    }
    func setReveal(_ reveal: ArtRevealMotion) {
        var next = parameters; next.reveal = reveal
        settings.parameters[settings.effect.rawValue] = next; save()
    }
    /// Any declared parameter: the spec clamps it, and sliders persist through the scheduler like `setStrength`.
    func setParameter(_ key: String, _ value: EffectParameterValue, spec: EffectParameterSpec?) {
        var next = parameters
        next[key] = spec?.clamp(value) ?? value
        settings.parameters[settings.effect.rawValue] = next
        if spec?.kind == .slider { saveLater() } else { save() }
    }
    func setActivation(_ angle: Double) {
        guard angle.isFinite else { return }
        settings.activation = angle.clamped(to: EffectTuning.activationRange).rounded(); saveLater()
    }
    func setCompletionFraction(_ fraction: Double) {
        guard fraction.isFinite else { return }
        settings.completionFraction = fraction.clamped(to: EffectTuning.completionRange); saveLater()
    }
    func setAppearance(_ appearance: AppearancePreference) { settings.appearance = appearance; save() }
    func setShowAngle(_ value: Bool) { settings.showAngle = value; save() }
    func removeParameters(for id: EffectID) { settings.parameters[id.rawValue] = nil; save() }
    /// Writes any coalesced change now; called before the process exits.
    func flush() { scheduler.flush() }

    private func save() { store.save(settings, for: UnfoldMyMacSettings.key) }
    private func saveLater() { scheduler.schedule { [weak self] in self?.save() } }
}
