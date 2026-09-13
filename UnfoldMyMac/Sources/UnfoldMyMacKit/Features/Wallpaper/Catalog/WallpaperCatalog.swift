import Foundation
import Observation
import UnfoldMyMacCore

/// The templates the gallery shows: bundled ones, the user's imports, the errors met loading either and the
/// lint warnings each template carries.
@MainActor @Observable final class WallpaperCatalog {
    private(set) var templates: [WallpaperTemplate] = []
    private(set) var errors: [String] = []
    private(set) var warnings: [String: [WallpaperTemplateWarning]] = [:]
    @ObservationIgnored private let shaders: WallpaperShaderCatalog
    @ObservationIgnored private let connectors: WallpaperConnectorRegistry
    @ObservationIgnored private var registry: WallpaperTemplateRegistry?

    init(shaders: WallpaperShaderCatalog, connectors: WallpaperConnectorRegistry = .standard) { self.shaders = shaders; self.connectors = connectors }

    var collection: WallpaperCollection { registry?.collection ?? .standard }
    var style: WallpaperStyle { registry?.style ?? .standard }
    func load() throws {
        registry = try WallpaperTemplateRegistry(shaders: shaders, connectors: connectors)
        sync()
    }
    func template(_ id: String) -> WallpaperTemplate? { templates.first { $0.id == id } }
    func assets(for id: String) -> WallpaperAssetResolver { registry?.assets(for: id) ?? .shared }
    func isImported(_ id: String) -> Bool { registry?.isImported(id) ?? false }
    /// `validate` proves the template renders before it is kept.
    func importTemplate(_ url: URL, validate: (WallpaperTemplate) throws -> Void) throws -> WallpaperTemplate {
        let template = try loaded().importTemplate(url, validate: validate)
        sync()
        return template
    }
    func rename(_ id: String, title: String) throws { try loaded().rename(id, title: title); sync() }
    func remove(_ id: String) throws { try loaded().remove(id); sync() }

    private func loaded() throws -> WallpaperTemplateRegistry {
        guard let registry else { throw WallpaperError.unavailable("The wallpaper collection has not loaded yet.") }
        return registry
    }
    private func sync() {
        guard let registry else { return }
        templates = registry.templates; errors = registry.errors; warnings = registry.warnings
    }
}
