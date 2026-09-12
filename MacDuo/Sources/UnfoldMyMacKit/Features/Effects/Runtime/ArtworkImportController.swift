import Foundation
import Observation
import UniformTypeIdentifiers
import UnfoldMyMacCore

/// Copies user images into the artwork library and keeps the registry in step. Outcomes come back as values;
/// the model decides what to select, stop or show.
@MainActor @Observable final class ArtworkImportController {
    private(set) var isImporting = false
    @ObservationIgnored private let library: ArtworkLibrary?
    @ObservationIgnored private let registry: EffectRegistry
    @ObservationIgnored private let filePicker: any FilePicking

    static let request = FilePickerRequest(title: "Add an image to \(AppIdentity.name)", prompt: "Add Image",
        message: "Your image is copied into \(AppIdentity.name). PNG, JPEG, HEIC, and other supported images, up to 50 MB.", types: [.image])

    init(library: ArtworkLibrary?, registry: EffectRegistry, filePicker: any FilePicking) {
        self.library = library; self.registry = registry; self.filePicker = filePicker
    }
    var isAvailable: Bool { library != nil }

    /// Presents the picker and returns the chosen file, or `nil` when the user cancels.
    func pickImage() async -> URL? {
        await withCheckedContinuation { continuation in filePicker.pick(Self.request) { continuation.resume(returning: $0) } }
    }
    /// Imports `url`; `nil` means nothing happened because an import is already running or the library is missing.
    func importImage(at url: URL) async throws -> EffectID? {
        guard !isImporting, let library else { return nil }
        isImporting = true
        defer { isImporting = false }
        let artwork = try await library.importImage(at: url)
        try registry.register(.artwork(artwork))
        return artwork.id
    }
    /// Re-registers the effect with its new credits; `false` when `id` is not an imported image.
    @discardableResult func updateCredits(of id: EffectID, title: String, author: String) throws -> Bool {
        guard let artwork = try library?.update(id: id, title: title, author: author) else { return false }
        registry.removeImported(artwork.id)
        try registry.register(.artwork(artwork))
        return true
    }
    /// Deletes the library's copy; the caller removes the registration once nothing renders it.
    func removeFromLibrary(_ id: EffectID) throws -> Bool {
        guard registry.entry(for: id).descriptor.isImported, let library else { return false }
        try library.remove(id)
        return true
    }
}
