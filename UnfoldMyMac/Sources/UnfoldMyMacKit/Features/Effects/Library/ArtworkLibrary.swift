import AppKit
import ImageIO
import Observation
import UniformTypeIdentifiers
import UnfoldMyMacCore

enum LibraryError: LocalizedError {
    case invalidImage, tooLarge, duplicateID, invalidIndex
    var errorDescription: String? {
        switch self {
        case .invalidImage: "This file could not be read as an image. Choose a PNG, JPEG, HEIC, TIFF, or another supported image."
        case .tooLarge: "Choose an image smaller than 50 MB and 200 megapixels."
        case .duplicateID: "An effect with this identifier is already in the library."
        case .invalidIndex: "The saved image library could not be read. Your image files have been kept."
        }
    }
}

/// App-owned copies outlive the original file. Only UUID-derived paths enter the
/// index, and index writes are atomic. A corrupt index is never silently overwritten.
@MainActor @Observable final class ArtworkLibrary {
    private(set) var records: [ImportedArtwork] = []
    private(set) var loadError: String?
    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("library.json") }
    init(directory: URL = AppSupportPaths.artwork) {
        self.directory = directory
        if FileManager.default.fileExists(atPath: indexURL.path) {
            do {
                records = try JSONDecoder().decode([ImportedArtwork].self, from: Data(contentsOf: indexURL))
                guard Set(records.map(\.id)).count == records.count else { throw LibraryError.invalidIndex }
            } catch { records = []; loadError = LibraryError.invalidIndex.localizedDescription }
        }
    }
    var definitions: [ArtworkDefinition] { records.map { $0.definition(in: directory) } }
    func importImage(at url: URL) async throws -> ArtworkDefinition {
        guard loadError == nil else { throw LibraryError.invalidIndex }
        // Image decoding, orientation, resizing, color conversion, and encoding are
        // off the main actor. No original metadata or external file dependency survives.
        let data = try await Task.detached(priority: .userInitiated) { try ImageFiles.normalizedPNG(at: url) }.value
        try Task.checkCancellation()
        let record = ImportedArtwork(id: UUID(), title: String(url.deletingPathExtension().lastPathComponent.prefix(80)), author: "You")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(record.filename)
        try data.write(to: destination, options: .atomic)
        do { try persist(records + [record]) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        records.append(record)
        return record.definition(in: directory)
    }
    func update(id: EffectID, title: String, author: String) throws -> ArtworkDefinition? {
        guard let index = records.firstIndex(where: { $0.effectID == id }) else { return nil }
        var next = records
        let title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let author = String(author.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        next[index].title = title.isEmpty ? "Untitled" : title
        next[index].author = author.isEmpty ? "You" : author
        try persist(next); records = next
        return next[index].definition(in: directory)
    }
    func remove(_ id: EffectID) throws {
        guard let record = records.first(where: { $0.effectID == id }) else { return }
        let next = records.filter { $0.id != record.id }
        try persist(next); records = next
        // The index is authoritative. If cleanup fails, an unused app-owned copy
        // may remain, but no catalog entry points to a deleted file.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(record.filename))
    }
    private func persist(_ records: [ImportedArtwork]) throws {
        guard loadError == nil else { throw LibraryError.invalidIndex }
        try JSONEncoder().encode(records).write(to: indexURL, options: .atomic)
    }
}
