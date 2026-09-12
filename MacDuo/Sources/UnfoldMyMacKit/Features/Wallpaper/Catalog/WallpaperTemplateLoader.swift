import Foundation
import UnfoldMyMacCore

/// Finds template documents in a directory: one folder per template (`<id>/template.json` beside its scene and
/// assets) or, accepted for one more release, a flat `<name>.json`. Order is the templates' `order`, then name.
enum WallpaperTemplateLoader {
    struct Item {
        let name: String
        let document: WallpaperTemplateDocument
        let assets: WallpaperAssetResolver
    }
    struct Problem {
        let name: String
        let error: any Error
    }
    static let templateFile = "template.json"
    static let reserved: Set<String> = ["Collection.json", "Style.json"]

    static func load(directory: URL, context: WallpaperTemplateSchema.Context) -> (items: [Item], problems: [Problem]) {
        var items: [Item] = [], problems: [Problem] = []
        let entries = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for url in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let file: URL, folder: URL?
            if isDirectory {
                file = url.appendingPathComponent(templateFile); folder = url
                guard FileManager.default.fileExists(atPath: file.path) else { continue }
            } else {
                guard url.pathExtension == "json", !reserved.contains(name) else { continue }
                file = url; folder = nil
            }
            do {
                let document = try WallpaperTemplateSchema.decode(try read(file), context: context)
                items.append(Item(name: name, document: document, assets: WallpaperAssetResolver(folder: folder)))
            } catch { problems.append(Problem(name: name, error: error)) }
        }
        items.sort { ($0.document.template.order ?? .max, $0.name) < ($1.document.template.order ?? .max, $1.name) }
        return (items, problems)
    }
    /// Reads at most the schema's byte cap plus one, so an oversized file is rejected without being loaded whole.
    static func read(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        return try handle.read(upToCount: WallpaperTemplateSchema.maximumBytes + 1) ?? Data()
    }
}
