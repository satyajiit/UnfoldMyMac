import Foundation
import Observation
import UnfoldMyMacCore

/// The templates the gallery shows: bundled ones, the user's imports, and the errors met loading either.
@MainActor @Observable final class WallpaperCatalog {
    private(set) var templates: [WallpaperTemplate] = []
    private(set) var errors: [String] = []
    @ObservationIgnored private let shaders: WallpaperShaderCatalog
    @ObservationIgnored private var registry: WallpaperTemplateRegistry?

    init(shaders: WallpaperShaderCatalog) { self.shaders = shaders }

    func load() throws {
        let registry = try WallpaperTemplateRegistry(shaders: shaders)
        self.registry = registry
        templates = registry.templates; errors = registry.errors
    }
    func template(_ id: String) -> WallpaperTemplate? { templates.first { $0.id == id } }
    /// `validate` proves the template renders before it is kept.
    func importTemplate(_ url: URL, validate: (WallpaperTemplate) throws -> Void) throws -> WallpaperTemplate {
        guard let registry else { throw WallpaperError.unavailable("The wallpaper collection has not loaded yet.") }
        let template = try registry.importTemplate(url, validate: validate)
        templates = registry.templates
        return template
    }
}
