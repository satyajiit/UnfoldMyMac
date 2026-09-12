import MetalKit
import UnfoldMyMacCore

/// Shader registrations are independent of templates, views and data providers.
@MainActor final class WallpaperShaderCatalog {
    struct Shader { let resource: String; let fragment: String; let dependencies: [String] }
    private var shaders: [String: Shader] = [:]
    private var pipelines: [String: MTLRenderPipelineState] = [:]
    let gpu: MTLDevice
    let queue: MTLCommandQueue
    init() throws {
        guard let gpu = MTLCreateSystemDefaultDevice(), let queue = gpu.makeCommandQueue() else {
            throw WallpaperError.unavailable("Metal is unavailable on this Mac.")
        }
        self.gpu = gpu; self.queue = queue
        shaders = Self.bundled
    }
    /// Every scene shader the app ships, keyed by the id templates name. Resolvable without a GPU.
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
        shaders[id] = Shader(resource: resource, fragment: fragment, dependencies: dependencies); pipelines[id] = nil
    }
    func contains(_ id: String) -> Bool { shaders[id] != nil }
    func pipeline(for id: String) throws -> MTLRenderPipelineState {
        if let cached = pipelines[id] { return cached }
        guard let shader = shaders[id] else { throw WallpaperError.missingShader(id) }
        let library = try library(resource: shader.resource)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "wallpaperVertex")
        descriptor.fragmentFunction = library.makeFunction(name: shader.fragment)
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        let pipeline = try gpu.makeRenderPipelineState(descriptor: descriptor)
        pipelines[id] = pipeline
        return pipeline
    }
    func library(resource: String) throws -> MTLLibrary {
        let dependencies = shaders.values.first { $0.resource == resource }?.dependencies ?? []
        let names = ["Common"] + dependencies + [resource]
        return try gpu.makeLibrary(source: names.map { try source($0) }.joined(separator: "\n"), options: nil)
    }
    private func source(_ name: String) throws -> String { try BundleResources.shaderSource(name, family: .wallpaper) }
}
