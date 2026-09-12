import Metal

/// Floating-point contract a shader unit is compiled with. `fast` is Metal's default and what every
/// bundled shader has always been compiled with; `safe` keeps IEEE semantics for shaders that need them.
enum ShaderMathMode: String, Hashable, Sendable, CaseIterable {
    case safe, relaxed, fast
    var metal: MTLMathMode {
        switch self { case .safe: .safe; case .relaxed: .relaxed; case .fast: .fast }
    }
}

/// One compile unit: ordered `.metal` resources of one family, compiled together into one library.
struct ShaderModule: Hashable, Sendable {
    let id: String
    let family: BundleResources.ShaderFamily
    let resources: [String]
    let mathMode: ShaderMathMode

    static func effect(_ resource: String, mathMode: ShaderMathMode = .fast) -> ShaderModule {
        ShaderModule(id: "effects/\(resource.lowercased())", family: .effects, resources: [resource], mathMode: mathMode)
    }
    /// Scene shaders share the wallpaper prelude and may name reusable source modules.
    static func wallpaper(_ id: String, resource: String, dependencies: [String] = [], mathMode: ShaderMathMode = .fast) -> ShaderModule {
        ShaderModule(id: "wallpaper/\(id)", family: .wallpaper, resources: ["Common"] + dependencies + [resource], mathMode: mathMode)
    }
    static let wallpaperEmblem = ShaderModule.wallpaper("emblem", resource: "Emblem")
    static let effects: [ShaderModule] = ["Frost", "Curtains", "ArtReveal", "Current", "Peekaboo"].map { effect($0) }
}
