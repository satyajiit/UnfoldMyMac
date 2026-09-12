import AppKit
import Observation
import UnfoldMyMacCore

@MainActor @Observable final class EffectRegistry {
    private(set) var entries: [EffectRegistration]
    private(set) var catalogError: String?
    /// Registrations that were ignored, with the reason. Duplicates are a content mistake, not a crash.
    private(set) var diagnostics: [String] = []
    var descriptors: [EffectDescriptor] { entries.map(\.descriptor) }
    init(entries: [EffectRegistration]) {
        precondition(!entries.isEmpty, "An effect registry needs at least one effect to fall back to.")
        var seen = Set<EffectID>()
        self.entries = []
        for entry in entries {
            if seen.insert(entry.descriptor.id).inserted { self.entries.append(entry) }
            else { diagnostics.append("Duplicate effect ‘\(entry.descriptor.id.rawValue)’ was ignored.") }
        }
    }
    func entry(for id: EffectID) -> EffectRegistration { entries.first { $0.descriptor.id == id } ?? entries[0] }
    func register(_ registration: EffectRegistration) throws {
        guard !entries.contains(where: { $0.descriptor.id == registration.descriptor.id }) else {
            throw LibraryError.duplicateID
        }
        entries.append(registration)
    }
    func removeImported(_ id: EffectID) {
        entries.removeAll { $0.descriptor.id == id && $0.descriptor.isImported }
    }
    static func builtIn() -> EffectRegistry {
        let registry = EffectRegistry(entries: BuiltInEffects.registrations)
        do {
            for artwork in try LibraryAssets.artworks() { try registry.register(.artwork(artwork)) }
        } catch { registry.catalogError = "The bundled artwork catalog could not be loaded: \(error.localizedDescription)" }
        return registry
    }
}
