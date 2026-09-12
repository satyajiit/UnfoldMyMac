import Foundation
import UnfoldMyMacCore

/// Every template the app can show: the bundled folders, then the user's library. Registration proves the shader,
/// marks and artwork exist; warnings from lint are kept per template for the gallery to surface.
@MainActor final class WallpaperTemplateRegistry {
    private(set) var templates: [WallpaperTemplate] = []
    private(set) var errors: [String] = []
    private(set) var warnings: [String: [WallpaperTemplateWarning]] = [:]
    let shaders: WallpaperShaderCatalog
    let collection: WallpaperCollection
    let library: WallpaperTemplateLibrary?
    private let connectors: WallpaperConnectorRegistry
    private var assets: [String: WallpaperAssetResolver] = [:]
    private var imported: Set<String> = []

    init(shaders: WallpaperShaderCatalog, connectors: WallpaperConnectorRegistry = .standard, library: WallpaperTemplateLibrary? = nil,
         loadUserTemplates: Bool = true) throws {
        self.shaders = shaders; self.connectors = connectors
        self.library = loadUserTemplates ? library ?? WallpaperTemplateLibrary() : library
        guard let bundled = BundleResources.wallpaperTemplates else { throw BundleResourcesError.missing("Resources/Wallpapers") }
        var collection = WallpaperCollection.standard
        do { collection = try WallpaperCollection.bundled() } catch { errors.append("Collection.json: \(error.localizedDescription)") }
        self.collection = collection
        let loaded = WallpaperTemplateLoader.load(directory: bundled, context: context)
        for problem in loaded.problems { errors.append("\(problem.name): \(problem.error.localizedDescription)") }
        for item in loaded.items {
            do {
                let template = item.document.template
                if let scene = template.scene {
                    guard let folder = item.assets.folder else { throw WallpaperError.invalidField("scene") }
                    guard !shaders.contains(template.shader) else { throw WallpaperError.duplicateID(template.shader) }
                    try shaders.register(template.shader, scene: scene, folder: folder)
                }
                try register(template, assets: item.assets, warnings: item.document.warnings)
            } catch { errors.append("\(item.name): \(error.localizedDescription)") }
        }
        if loadUserTemplates, let library = self.library { loadImported(library) }
    }
    /// What lint may check against: the collection's categories, the connectors and namespaces this build has.
    var context: WallpaperTemplateSchema.Context {
        .init(categories: Set(collection.categories.map(\.id)), connectors: Set(connectors.connectors.filter { !$0.implicit }.map(\.id)),
              namespaces: Set(connectors.connectors.flatMap(\.namespaces)).union(["countdown"]), sceneParameters: shaders.parameterKeys)
    }
    func register(_ template: WallpaperTemplate, assets: WallpaperAssetResolver = .shared, warnings: [WallpaperTemplateWarning] = []) throws {
        let checked = try template.validated()
        guard !templates.contains(where: { $0.id == checked.id }) else { throw WallpaperError.duplicateID(checked.id) }
        guard shaders.contains(checked.shader) else { throw WallpaperError.missingShader(checked.shader) }
        if let emblem = checked.emblem, assets.mark(emblem.asset) == nil { throw WallpaperError.missingAsset(emblem.asset) }
        if let image = checked.image, assets.image(image) == nil { throw WallpaperError.missingAsset(image) }
        templates.append(checked)
        self.assets[checked.id] = assets
        if !warnings.isEmpty { self.warnings[checked.id] = warnings }
    }
    func assets(for id: String) -> WallpaperAssetResolver { assets[id] ?? .shared }
    func isImported(_ id: String) -> Bool { imported.contains(id) }
    /// Keeps the file exactly as given once it decodes, names only a bundled scene and `validate` proves it renders.
    func importTemplate(_ url: URL, validate: (WallpaperTemplate) throws -> Void) throws -> WallpaperTemplate {
        guard let library else { throw WallpaperError.unavailable("Imported templates are not available here.") }
        let data = try WallpaperTemplateLoader.read(url)
        let document = try WallpaperTemplateSchema.decode(data, context: context)
        let template = try Self.importable(document.template)
        guard !templates.contains(where: { $0.id == template.id }) else { throw WallpaperError.duplicateID(template.id) }
        guard shaders.contains(template.shader) else { throw WallpaperError.missingShader(template.shader) }
        try validate(template)
        try library.add(data, template: template)
        try register(template, warnings: document.warnings)
        imported.insert(template.id)
        return template
    }
    func rename(_ id: String, title: String) throws {
        guard let library, imported.contains(id), let index = templates.firstIndex(where: { $0.id == id }) else { return }
        guard let record = try library.rename(id, title: title) else { return }
        templates[index].title = record.title ?? templates[index].title
    }
    func remove(_ id: String) throws {
        guard let library, imported.contains(id) else { return }
        try library.remove(id)
        templates.removeAll { $0.id == id }
        imported.remove(id); assets[id] = nil; warnings[id] = nil
    }
    private func loadImported(_ library: WallpaperTemplateLibrary) {
        if let error = library.loadError { errors.append(error) }
        for record in library.records {
            do {
                let document = try WallpaperTemplateSchema.decode(try library.data(for: record), context: context)
                var template = try Self.importable(document.template)
                if let title = record.title { template.title = title }
                try register(template, warnings: document.warnings)
                imported.insert(template.id)
            } catch { errors.append("Custom template \(record.filename): \(error.localizedDescription)") }
        }
    }
    /// Imports may name a bundled scene, never ship their own shader source.
    private static func importable(_ template: WallpaperTemplate) throws -> WallpaperTemplate {
        guard template.scene == nil else { throw WallpaperError.invalidField("scene") }
        return template
    }
}
