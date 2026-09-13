import Foundation
import Metal

/// Floating-point contract a shader unit is compiled with. `fast` is Metal's default and what every
/// bundled shader has always been compiled with; `safe` keeps IEEE semantics for shaders that need them.
enum ShaderMathMode: String, Hashable, Sendable, CaseIterable {
    case safe, relaxed, fast
    var metal: MTLMathMode {
        switch self { case .safe: .safe; case .relaxed: .relaxed; case .fast: .fast }
    }
}

/// Where one `.metal` text comes from: a shared file in the bundle's shader families, or a template-owned
/// scene file beside its `template.json`.
enum ShaderSource: Hashable, Sendable {
    case bundled(family: BundleResources.ShaderFamily, name: String)
    case file(URL)
    /// The path `script/compile_shaders.sh` reads, relative to the resource bundle.
    var bundlePath: String {
        switch self {
        case .bundled(let family, let name): "\(family.rawValue)/\(name).metal"
        case .file(let url): BundleResources.relativePath(of: url) ?? url.path
        }
    }
    func load() throws -> String {
        switch self {
        case .bundled(let family, let name): try BundleResources.shaderSource(name, family: family)
        case .file(let url): try String(contentsOf: url, encoding: .utf8)
        }
    }
}

/// One compile unit: ordered `.metal` sources compiled together into one library.
struct ShaderModule: Hashable, Sendable {
    let id: String
    let resources: [ShaderSource]
    let mathMode: ShaderMathMode

    static func effect(_ resource: String, mathMode: ShaderMathMode = .fast) -> ShaderModule {
        ShaderModule(id: "effects/\(resource.lowercased())", resources: [.bundled(family: .effects, name: resource)], mathMode: mathMode)
    }
    /// Scene shaders share the wallpaper prelude and may name reusable modules from the shared family.
    static func wallpaper(_ id: String, source: ShaderSource, dependencies: [String] = [], mathMode: ShaderMathMode = .fast) -> ShaderModule {
        ShaderModule(id: "wallpaper/\(id)", resources: [.bundled(family: .wallpaper, name: "Common")] + dependencies.map { .bundled(family: .wallpaper, name: $0) } + [source], mathMode: mathMode)
    }
    static let wallpaperEmblem = ShaderModule.wallpaper("emblem", source: .bundled(family: .wallpaper, name: "Emblem"))
    static let effects: [ShaderModule] = ["Frost", "Curtains", "ArtReveal", "Current", "Peekaboo", "LidImpact"].map { effect($0) }
}
