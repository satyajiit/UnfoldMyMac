import AppKit
import Observation
import UnfoldMyMacCore

@MainActor @Observable final class EffectRegistry {
    private(set) var entries: [EffectRegistration]
    private(set) var catalogError: String?
    var descriptors: [EffectDescriptor] { entries.map(\.descriptor) }
    init(entries: [EffectRegistration]) {
        precondition(!entries.isEmpty && Set(entries.map(\.descriptor.id)).count == entries.count)
        self.entries = entries
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
