import UnfoldMyMacCore

/// Shader registrations are independent of templates, views, data providers and the GPU.
@MainActor final class WallpaperShaderCatalog {
    struct Shader { let resource: String; let fragment: String; let dependencies: [String] }
    private var shaders: [String: Shader]
    init() { shaders = Self.bundled }
    /// Every scene shader the app ships, keyed by the id templates name.
    static let bundled: [String: Shader] = [
        "vice-countdown": Shader(resource: "ViceCountdown", fragment: "viceCountdownFragment", dependencies: []),
        "aurora-observatory": Shader(resource: "AuroraObservatory", fragment: "auroraObservatoryFragment", dependencies: []),
        "pulse": Shader(resource: "Pulse", fragment: "pulseFragment", dependencies: []),
        "claude": Shader(resource: "Claude", fragment: "claudeFragment", dependencies: []),
        "daydream": Shader(resource: "Daydream", fragment: "daydreamFragment", dependencies: []),
        "codex-foundry": Shader(resource: "CodexFoundry", fragment: "codexFoundryFragment", dependencies: []),
        "grok-horizon": Shader(resource: "GrokHorizon", fragment: "grokHorizonFragment", dependencies: []),
        "github-city": Shader(resource: "GitHubCity", fragment: "githubCityFragment", dependencies: []),
        "codex-control": Shader(resource: "CodexControl", fragment: "codexControlFragment", dependencies: []),
        "lights-out": Shader(resource: "LightsOut", fragment: "lightsOutFragment", dependencies: ["RaceCar", "RaceMaterials"]),
    ]
    func register(_ id: String, resource: String, fragment: String, dependencies: [String] = []) {
        shaders[id] = Shader(resource: resource, fragment: fragment, dependencies: dependencies)
    }
    func contains(_ id: String) -> Bool { shaders[id] != nil }
    func shader(for id: String) throws -> Shader {
        guard let shader = shaders[id] else { throw WallpaperError.missingShader(id) }
        return shader
    }
    func module(for id: String) throws -> ShaderModule {
        let shader = try shader(for: id)
        return .wallpaper(id, resource: shader.resource, dependencies: shader.dependencies)
    }
    /// Every registered scene unit plus the emblem pass, for precompilation and diagnostics.
    var modules: [ShaderModule] {
        shaders.keys.sorted().compactMap { try? module(for: $0) } + [.wallpaperEmblem]
    }
}
