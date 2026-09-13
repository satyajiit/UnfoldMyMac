import AppKit
import Observation
import UnfoldMyMacCore

/// Every effect the app can render, keyed by id. Unknown ids resolve to a non-capture fallback and say so; the
/// registry never crashes on content mistakes, it reports them.
@MainActor @Observable final class EffectRegistry {
    private(set) var entries: [EffectRegistration]
    private(set) var catalogError: String?
    /// Registrations that were ignored or substituted, with the reason.
    private(set) var diagnostics: [String] = []
    /// The effect that stands in for an unknown or removed choice.
    let fallback: EffectID
    /// The effect rendered for every design while Reduce Transparency is on.
    let reduceTransparencyFallback: EffectID
    var descriptors: [EffectDescriptor] { entries.map(\.descriptor) }

    init(entries: [EffectRegistration], fallback: EffectID = .veil, reduceTransparencyFallback: EffectID = .fade) {
        var seen = Set<EffectID>(), kept: [EffectRegistration] = [], problems: [String] = []
        for entry in entries {
            if seen.insert(entry.descriptor.id).inserted { kept.append(entry) }
            else { problems.append("Duplicate effect ‘\(entry.descriptor.id.rawValue)’ was ignored.") }
        }
        if kept.isEmpty {
            kept = [Self.builtInVeil]
            problems.append("The effect catalog was empty; Veil was added so something can render.")
        }
        let fallbackID = seen.contains(fallback) || kept[0].descriptor.id == fallback ? fallback : kept[0].descriptor.id
        self.entries = kept
        self.fallback = fallbackID
        self.reduceTransparencyFallback = seen.contains(reduceTransparencyFallback) ? reduceTransparencyFallback : fallbackID
        diagnostics = problems
    }
    func entry(for id: EffectID) -> EffectRegistration? { entries.first { $0.descriptor.id == id } }
    /// The entry for `id`, or the fallback with `substituted` set so the caller can tell the user.
    func resolve(_ id: EffectID) -> (entry: EffectRegistration, substituted: Bool) {
        if let entry = entry(for: id) { return (entry, false) }
        return (entry(for: fallback) ?? entries[0], true)
    }
    func title(for id: EffectID) -> String { entry(for: id)?.descriptor.title ?? id.rawValue }
    func register(_ registration: EffectRegistration) throws {
        guard entry(for: registration.descriptor.id) == nil else { throw LibraryError.duplicateID }
        entries.append(registration)
    }
    func removeImported(_ id: EffectID) {
        entries.removeAll { $0.descriptor.id == id && $0.descriptor.isImported }
    }
    /// The bundled catalog: `Effects.json` first, then the artwork manifest. Entries naming a renderer this build
    /// lacks are skipped with a diagnostic; a catalog that fails to load leaves Veil and reports why.
    static func builtIn() -> EffectRegistry {
        var entries: [EffectManifestEntry] = [], problems: [String] = []
        var fallback = EffectID.veil, reduceTransparency = EffectID.fade
        do {
            let manifest = try EffectAssets.manifest()
            fallback = manifest.fallback; reduceTransparency = manifest.reduceTransparencyFallback
            entries = manifest.effects
        } catch { problems.append("The effect catalog could not be loaded: \(error.localizedDescription)") }
        do { entries += try EffectAssets.artworkEntries() }
        catch { problems.append("The bundled artwork catalog could not be loaded: \(error.localizedDescription)") }
        let registry = EffectRegistry(manifestEntries: entries, fallback: fallback, reduceTransparencyFallback: reduceTransparency)
        registry.catalogError = problems.isEmpty ? nil : problems.joined(separator: "\n")
        return registry
    }
    /// Catalog entries bound to their factories; one naming a renderer this build lacks is skipped with a diagnostic.
    convenience init(manifestEntries: [EffectManifestEntry], fallback: EffectID = .veil, reduceTransparencyFallback: EffectID = .fade) {
        var registrations: [EffectRegistration] = [], skipped: [String] = []
        for entry in manifestEntries {
            guard let factory = EffectRendererFactories.factory(for: entry) else {
                skipped.append("Effect ‘\(entry.id.rawValue)’ names the renderer ‘\(entry.renderer)’, which this build does not have."); continue
            }
            registrations.append(.init(entry: entry, factory: factory, coverURL: EffectAssets.cover(entry.cover)))
        }
        self.init(entries: registrations, fallback: fallback, reduceTransparencyFallback: reduceTransparencyFallback)
        for problem in skipped { diagnostics.append(problem) }
    }
    private static var builtInVeil: EffectRegistration {
        .init(descriptor: .init(id: .veil, title: "Veil", subtitle: "A quiet layer of glass.", detail: "", symbol: "square.stack.3d.up", tags: ["Glass"]),
              makeRenderer: { _ in NativeEffectRenderer(kind: .veil) })
    }
}
