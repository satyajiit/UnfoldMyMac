import Foundation
import UnfoldMyMacCore

/// Builds scene pipelines from the one GPU context and shader catalog, and decides which artwork a template
/// renders with. The only place outside `Rendering/` that knows a pipeline needs a GPU.
@MainActor final class WallpaperPipelineFactory {
    private let gpu: GPUContext
    let shaders: WallpaperShaderCatalog

    init(gpu: GPUContext, shaders: WallpaperShaderCatalog) { self.gpu = gpu; self.shaders = shaders }

    /// The user's own background when the template accepts one and the preference asks for it.
    static func backgroundImage(for template: WallpaperTemplate, customBackground: Bool) -> URL? {
        customBackground && template.image != nil && template.allowsCustomBackground != false ? WallpaperPaths.background : nil
    }
    func make(_ template: WallpaperTemplate, imageURL: URL? = nil, assets: WallpaperAssetResolver = .shared) throws -> WallpaperPipeline {
        try WallpaperPipeline(template: template, gpu: gpu, shaders: shaders, imageURL: imageURL, assets: assets)
    }
    func validate(_ template: WallpaperTemplate, assets: WallpaperAssetResolver = .shared) throws { _ = try make(template, assets: assets) }
}
