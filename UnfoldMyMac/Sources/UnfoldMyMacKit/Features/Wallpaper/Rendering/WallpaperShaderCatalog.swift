import Foundation
import UnfoldMyMacCore

/// Scene shaders by id. Every bundled scene registers from its template folder; imported templates may only name
/// a scene that is already here. Independent of views, data providers and the GPU.
@MainActor final class WallpaperShaderCatalog {
    struct Scene {
        let module: ShaderModule
        let fragment: String
        let parameters: [WallpaperSceneParameter]
        let nativeResolution: Bool
        let liveInputs: Bool
    }
    private var scenes: [String: Scene] = [:]
    init() {}

    /// Registers a template-owned scene: its `.metal` beside `template.json`, after the shared prelude and modules.
    func register(_ id: String, scene: WallpaperSceneSource, folder: URL) throws {
        guard let url = WallpaperAssetResolver(folder: folder).shader(scene.source) else { throw WallpaperError.missingAsset(scene.source) }
        for module in scene.dependencies ?? [] where BundleResources.shader(module, family: .wallpaper) == nil { throw WallpaperError.missingAsset(module) }
        let mode = scene.mathMode.flatMap(ShaderMathMode.init(rawValue:)) ?? .fast
        scenes[id] = Scene(module: .wallpaper(id, source: .file(url), dependencies: scene.dependencies ?? [], mathMode: mode),
                           fragment: scene.fragment, parameters: scene.params ?? [], nativeResolution: scene.resolution == "native", liveInputs: scene.liveInputs == true)
    }
    func contains(_ id: String) -> Bool { scenes[id] != nil }
    func scene(for id: String) throws -> Scene {
        guard let scene = scenes[id] else { throw WallpaperError.missingShader(id) }
        return scene
    }
    /// Declared parameter keys by scene id, for lint.
    var parameterKeys: [String: Set<String>] { scenes.mapValues { Set($0.parameters.map(\.key)) } }
    /// Every registered scene unit plus the emblem pass, for precompilation and diagnostics.
    var modules: [ShaderModule] { scenes.keys.sorted().compactMap { scenes[$0]?.module } + [.wallpaperEmblem] }
}
