import AppKit
import Observation
import UnfoldMyMacCore

@MainActor protocol EffectRenderer: AnyObject {
    var view: NSView { get }
    var ready: Bool { get }
    var animatesWithTime: Bool { get }
    var lastGPUTime: Double { get }
    func prepare(size: CGSize, scale: CGFloat)
    func update(_ context: EffectContext)
    func stop()
}

extension EffectRenderer {
    var animatesWithTime: Bool { false }
    var lastGPUTime: Double { 0 }
}

@MainActor protocol DesktopFrameConsuming: EffectRenderer {
    func receive(_ frame: DesktopFrame)
}

@MainActor struct EffectRegistration {
    let descriptor: EffectDescriptor
    let makeRenderer: () throws -> any EffectRenderer
}

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

extension EffectRegistration {
    static func artwork(_ artwork: ArtworkDefinition) -> EffectRegistration {
        .init(descriptor: artwork.descriptor, makeRenderer: { ArtRevealRenderer(pipeline: try ArtRevealPipeline(artwork: artwork)) })
    }
}
