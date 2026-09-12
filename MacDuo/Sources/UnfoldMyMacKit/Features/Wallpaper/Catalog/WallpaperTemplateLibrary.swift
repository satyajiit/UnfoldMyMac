import Foundation
import Observation
import UnfoldMyMacCore

/// One imported template: the original bytes live in `<uuid>.json`; a rename lives in the index, never in the file.
struct ImportedTemplate: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let templateID: String
    var title: String?
    var filename: String { id.uuidString + ".json" }
}

/// The user's imported templates, mirroring `ArtworkLibrary`: a `library.json` index over app-owned files under
/// Application Support. Files from releases before the index are indexed once on first use.
@MainActor @Observable final class WallpaperTemplateLibrary {
    private(set) var records: [ImportedTemplate] = []
    private(set) var loadError: String?
    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("library.json") }

    init(directory: URL = WallpaperPaths.templates) {
        self.directory = directory
        if FileManager.default.fileExists(atPath: indexURL.path) {
            do {
                records = try JSONDecoder().decode([ImportedTemplate].self, from: Data(contentsOf: indexURL))
                guard Set(records.map(\.id)).count == records.count, Set(records.map(\.templateID)).count == records.count else { throw WallpaperError.invalidData }
            } catch { records = []; loadError = "The saved wallpaper template index could not be read. Your template files have been kept." }
        } else if FileManager.default.fileExists(atPath: directory.path) {
            records = Self.indexExistingFiles(in: directory)
            if !records.isEmpty { try? persist(records) }
        }
    }
    func data(for record: ImportedTemplate) throws -> Data { try WallpaperTemplateLoader.read(directory.appendingPathComponent(record.filename)) }
    /// Keeps `data` exactly as imported; the caller has already decoded and validated it as `template`.
    @discardableResult func add(_ data: Data, template: WallpaperTemplate) throws -> ImportedTemplate {
        guard loadError == nil else { throw WallpaperError.unavailable(loadError ?? "") }
        guard !records.contains(where: { $0.templateID == template.id }) else { throw WallpaperError.duplicateID(template.id) }
        let record = ImportedTemplate(id: UUID(), templateID: template.id, title: nil)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(record.filename)
        try data.write(to: destination, options: .atomic)
        do { try persist(records + [record]) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        records.append(record)
        return record
    }
    @discardableResult func rename(_ templateID: String, title: String) throws -> ImportedTemplate? {
        guard let index = records.firstIndex(where: { $0.templateID == templateID }) else { return nil }
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        var next = records
        next[index].title = trimmed.isEmpty ? nil : trimmed
        try persist(next); records = next
        return next[index]
    }
    func remove(_ templateID: String) throws {
        guard let record = records.first(where: { $0.templateID == templateID }) else { return }
        let next = records.filter { $0.id != record.id }
        try persist(next); records = next
        // The index is authoritative; a file left behind after a failed delete is never listed.
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(record.filename))
    }
    private func persist(_ records: [ImportedTemplate]) throws {
        guard loadError == nil else { throw WallpaperError.unavailable(loadError ?? "") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: indexURL, options: .atomic)
    }
    /// Files written by the release before the index: `<uuid>.json`, named by the UUID they were saved under.
    private static func indexExistingFiles(in directory: URL) -> [ImportedTemplate] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var records: [ImportedTemplate] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "json" {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                  let document = try? WallpaperTemplateSchema.decode(try WallpaperTemplateLoader.read(file)),
                  !records.contains(where: { $0.templateID == document.template.id }) else { continue }
            records.append(ImportedTemplate(id: id, templateID: document.template.id, title: nil))
        }
        return records
    }
}
