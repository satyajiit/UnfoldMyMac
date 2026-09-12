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

struct ImportedArtwork: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var effectID: EffectID { .init(rawValue: "import.\(id.uuidString.lowercased())") }
    var filename: String { "\(id.uuidString.lowercased()).png" }
    func definition(in directory: URL) -> ArtworkDefinition {
        let image = directory.appendingPathComponent(filename)
        return .init(descriptor: .init(id: effectID, title: title, subtitle: "Your art. A new way to open.",
            detail: "Your image parts to reveal the desktop and comes together as the lid closes. Choose a reveal and adjust its depth below. Images fill the display without stretching; edges may be cropped.",
            symbol: UnfoldMyMacIcon.image.rawValue, parameterTitle: "Depth & edge light", renderingLabel: "Your image",
            category: .image, tags: ["Imported", "Personal"], author: author, credit: "Imported from a local file",
            coverURL: image, isImported: true, defaultReveal: .curved), imageURL: image)
    }
}

/// App-owned copies outlive the original file. Only UUID-derived paths enter the
/// index, and index writes are atomic. A corrupt index is never silently overwritten.
@MainActor @Observable final class ArtworkLibrary {
    private(set) var records: [ImportedArtwork] = []
    private(set) var loadError: String?
    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("library.json") }
    static func defaultDirectory() -> URL {
        let neu = URL.applicationSupportDirectory.appendingPathComponent("UnfoldMyMac/Artwork", isDirectory: true)
        let old = URL.applicationSupportDirectory.appendingPathComponent("Luma/Artwork", isDirectory: true)
        migrateIfNeeded(from: old, to: neu)
        return neu
    }
    private static func migrateIfNeeded(from old: URL, to neu: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: neu.path), fm.fileExists(atPath: old.path) else { return }
        do {
            try fm.createDirectory(at: neu.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: old, to: neu)
            let parent = old.deletingLastPathComponent()
            if let items = try? fm.contentsOfDirectory(atPath: parent.path), items.isEmpty { try? fm.removeItem(at: parent) }
        } catch {}
    }
    init(directory: URL = ArtworkLibrary.defaultDirectory()) {
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

/// ImageIO applies EXIF orientation before either thumbnails or renderer textures
/// are created. Opaque sRGB copies make translucent source images seal consistently.
enum ImageFiles {
    static func thumbnail(at url: URL, maxPixelSize: Int = 720) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
    static func normalizedPNG(at url: URL) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw LibraryError.invalidImage }
        guard (values.fileSize ?? Int.max) <= 50 * 1024 * 1024 else { throw LibraryError.tooLarge }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0 else { throw LibraryError.invalidImage }
        guard Double(width) * Double(height) <= 200_000_000 else { throw LibraryError.tooLarge }
        guard let image = thumbnail(at: url, maxPixelSize: 4096),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw LibraryError.invalidImage
        }
        context.setFillColor(CGColor(red: 0.025, green: 0.025, blue: 0.03, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let result = context.makeImage() else { throw LibraryError.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw LibraryError.invalidImage }
        CGImageDestinationAddImage(destination, result, nil)
        guard CGImageDestinationFinalize(destination) else { throw LibraryError.invalidImage }
        return output as Data
    }
}
