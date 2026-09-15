import Foundation
import UnfoldMyMacCore

/// The provider's one-per-process GPU and catalog, built lazily on first use.
///
/// The extension is spawned by WallpaperAgent, not by the app, so it cannot share the app's
/// `AppDependencies`. It builds the same three collaborators the app's wallpaper feature does — a
/// `GPUContext`, a `WallpaperShaderCatalog` and a `WallpaperCatalog` — against the same bundled templates,
/// which `BundleResources` finds because the appex carries its own copy of the Kit resource bundle.
@MainActor final class WallpaperProviderEnvironment {
    static let shared = WallpaperProviderEnvironment()

    private(set) var gpu: GPUContext?
    private(set) var catalog: WallpaperCatalog?
    private(set) var factory: WallpaperPipelineFactory?
    private var loadFailure: String?
    private var loaded = false

    private init() {}

    /// Builds the GPU context and loads the bundled templates once. Failures are recorded, not thrown:
    /// a provider that cannot render must still answer the host's XPC calls.
    func load() {
        guard !loaded else { return }
        loaded = true
        do {
            let gpu = try GPUContext()
            let shaders = WallpaperShaderCatalog()
            let catalog = WallpaperCatalog(shaders: shaders)
            try catalog.load()
            self.gpu = gpu
            self.catalog = catalog
            factory = WallpaperPipelineFactory(gpu: gpu, shaders: shaders)
            WallpaperProviderLog.note("catalog loaded — \(catalog.templates.count) templates, device \(gpu.device.name)")
        } catch {
            loadFailure = String(describing: error)
            WallpaperProviderLog.fault("catalog failed to load: \(String(describing: error))")
        }
    }

    /// The catalog's shared type styles, which the readout layers render with. The same sheet the app's
    /// desktop windows use, so a scene reads identically wherever it is drawn.
    var style: WallpaperStyle {
        load()
        return catalog?.style ?? .standard
    }

    /// Templates eligible to be offered as a system wallpaper, in gallery order.
    var offeredTemplates: [WallpaperTemplate] {
        load()
        return catalog?.templates ?? []
    }

    func template(_ id: String) -> WallpaperTemplate? {
        load()
        return catalog?.template(id)
    }

    /// A pipeline for `id`, using the template's own asset resolver so imported artwork still resolves.
    func makePipeline(templateID: String) throws -> WallpaperPipeline {
        load()
        guard let factory, let catalog else {
            throw WallpaperError.unavailable(loadFailure ?? "The wallpaper renderer is unavailable.")
        }
        guard let template = catalog.template(templateID) else {
            throw WallpaperError.unavailable("No wallpaper template named ‘\(templateID)’.")
        }
        return try factory.make(template, assets: catalog.assets(for: templateID))
    }
}
