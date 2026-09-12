import Foundation
import UnfoldMyMacCore

@MainActor final class WallpaperTemplateRegistry {
    private(set) var templates: [WallpaperTemplate] = []
    private(set) var errors: [String] = []
    let shaders: WallpaperShaderCatalog
    init(shaders: WallpaperShaderCatalog, loadUserTemplates: Bool = true) throws {
        self.shaders = shaders
        guard let bundled = BundleResources.wallpaperTemplates else { throw BundleResourcesError.missing("Resources/Wallpapers") }
        try load(directory: bundled)
        if loadUserTemplates, FileManager.default.fileExists(atPath: WallpaperPaths.templates.path) {
            do { try load(directory: WallpaperPaths.templates) }
            catch { errors.append("Custom templates: \(error.localizedDescription)") }
        }
    }
    func register(_ template: WallpaperTemplate) throws {
        let checked = try template.validated()
        guard !templates.contains(where: { $0.id == checked.id }) else { throw WallpaperError.duplicateID(checked.id) }
        guard shaders.contains(checked.shader) else { throw WallpaperError.missingShader(checked.shader) }
        if let emblem = checked.emblem, BundleResources.wallpaperMark(emblem.asset) == nil {
            throw WallpaperError.unavailable("The original logo ‘\(emblem.asset)’ is not installed.")
        }
        if let image = checked.image, BundleResources.artwork(image) == nil {
            throw WallpaperError.unavailable("The template’s artwork ‘\(image)’ is not installed.")
        }
        templates.append(checked)
    }
    /// `validate` builds whatever the caller needs to prove the template renders before it is kept.
    func importTemplate(_ url: URL, validate: (WallpaperTemplate) throws -> Void) throws -> WallpaperTemplate {
        let template = try decode(url)
        guard !templates.contains(where: { $0.id == template.id }), shaders.contains(template.shader) else {
            if templates.contains(where: { $0.id == template.id }) { throw WallpaperError.duplicateID(template.id) }
            throw WallpaperError.missingShader(template.shader)
        }
        try validate(template)
        try FileManager.default.createDirectory(at: WallpaperPaths.templates, withIntermediateDirectories: true)
        let destination = WallpaperPaths.templates.appendingPathComponent(UUID().uuidString + ".json")
        try JSONEncoder().encode(template).write(to: destination, options: .atomic)
        try register(template)
        return template
    }
    private func load(directory: URL) throws {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            do { try register(decode(url)) }
            catch { errors.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
    }
    private func decode(_ url: URL) throws -> WallpaperTemplate {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: 131_073) ?? Data()
        guard data.count <= 131_072 else { throw WallpaperError.invalidTemplate }
        return try JSONDecoder().decode(WallpaperTemplate.self, from: data).validated()
    }
}
