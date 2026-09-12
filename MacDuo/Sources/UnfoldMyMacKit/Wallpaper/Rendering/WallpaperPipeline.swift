import MetalKit
import UnfoldMyMacCore

struct WallpaperUniforms {
    var size: SIMD2<Float>
    var time: Float
    var energy: Float
    var accent: SIMD4<Float>
    var background: SIMD4<Float>
    var channels: SIMD4<Float>
}

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
        register("vice-countdown", resource: "ViceCountdown", fragment: "viceCountdownFragment")
        register("aurora-observatory", resource: "AuroraObservatory", fragment: "auroraObservatoryFragment")
        register("pulse", resource: "Pulse", fragment: "pulseFragment")
        register("claude", resource: "Claude", fragment: "claudeFragment")
        register("daydream", resource: "Daydream", fragment: "daydreamFragment")
        register("codex-foundry", resource: "CodexFoundry", fragment: "codexFoundryFragment")
        register("grok-horizon", resource: "GrokHorizon", fragment: "grokHorizonFragment")
        register("github-city", resource: "GitHubCity", fragment: "githubCityFragment")
        register("codex-control", resource: "CodexControl", fragment: "codexControlFragment")
        register("lights-out", resource: "LightsOut", fragment: "lightsOutFragment", dependencies: ["RaceCar", "RaceMaterials"])
    }
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
    private func source(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "metal", subdirectory: "WallpaperShaders") else { throw CocoaError(.fileNoSuchFile) }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor final class WallpaperPipeline {
    let catalog: WallpaperShaderCatalog
    let template: WallpaperTemplate
    private let pipeline: MTLRenderPipelineState
    private let texture: MTLTexture
    private let emblem: WallpaperEmblemPipeline?
    private let gridTexture: WallpaperGridTexture
    init(template: WallpaperTemplate, catalog: WallpaperShaderCatalog, imageURL: URL? = nil) throws {
        self.catalog = catalog; self.template = template
        gridTexture = try WallpaperGridTexture(device: catalog.gpu)
        pipeline = try catalog.pipeline(for: template.shader)
        emblem = try template.emblem.map { try WallpaperEmblemPipeline(placement: $0, catalog: catalog) }
        let bundledImage = template.image.flatMap { Bundle.module.url(forResource: $0, withExtension: "png", subdirectory: "Resources/Artwork") }
        if template.image != nil && imageURL == nil && bundledImage == nil { throw CocoaError(.fileNoSuchFile) }
        if let url = imageURL ?? bundledImage {
            texture = try MTKTextureLoader(device: catalog.gpu).newTexture(URL: url, options: [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue])
        } else {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
            guard let fallback = catalog.gpu.makeTexture(descriptor: descriptor) else { throw WallpaperError.unavailable("Could not create a wallpaper texture.") }
            var pixel: UInt32 = 0xff101010
            fallback.replace(region: MTLRegionMake2D(0,0,1,1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
            texture = fallback
        }
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, time: Double, energy: Double, channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        var uniforms = WallpaperUniforms(size: SIMD2(Float(size.width), Float(size.height)), time: Float(time.truncatingRemainder(dividingBy: 3600)),
            energy: Float(min(1, max(0, energy))), accent: color(template.accent), background: color(template.background), channels: channels)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<WallpaperUniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(gridTexture.texture(for: grid), index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        emblem?.encode(encoder, size: size)
        encoder.endEncoding()
        return true
    }
    private func color(_ hex: UInt32) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 255)/255, Float((hex >> 8) & 255)/255, Float(hex & 255)/255, 1)
    }
}
