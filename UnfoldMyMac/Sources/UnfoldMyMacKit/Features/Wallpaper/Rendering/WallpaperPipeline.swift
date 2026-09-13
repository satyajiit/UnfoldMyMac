import Metal
import UnfoldMyMacCore

/// Matches Common.metal exactly; new live vectors are appended after the existing 96-byte layout.
struct WallpaperUniforms {
    var size: SIMD2<Float>
    var time: Float
    var energy: Float
    var accent: SIMD4<Float>
    var background: SIMD4<Float>
    var channels: SIMD4<Float>
    /// `float4 params[2]` in `Common.metal`: the scene's declared parameters in declaration order.
    var params: (SIMD4<Float>, SIMD4<Float>)
    var interaction: SIMD4<Float>
    /// Battery, daylight, Reduce Motion, persistent external power.
    var environment: SIMD4<Float>
    var motion: SIMD4<Float>
}

/// One template's scene shader, artwork texture, data grid and optional emblem pass.
@MainActor final class WallpaperPipeline: MetalPipeline {
    let gpu: GPUContext
    let template: WallpaperTemplate
    /// The personal background this pipeline was built with, if any; part of its identity for caches.
    let imageURL: URL?
    let surface: SurfaceConfiguration
    let usesLiveInputs: Bool
    /// Changes with shader source/dependencies and template content, so companion stills follow artwork updates.
    let backdropKey: String
    private let pipeline: MTLRenderPipelineState
    private let texture: MTLTexture
    private let emblem: WallpaperEmblemPipeline?
    private let gridTexture: WallpaperGridTexture
    private let accent: SIMD4<Float>
    private let background: SIMD4<Float>
    private let params: (SIMD4<Float>, SIMD4<Float>)

    init(template: WallpaperTemplate, gpu: GPUContext, shaders: WallpaperShaderCatalog, imageURL: URL? = nil, assets: WallpaperAssetResolver = .shared) throws {
        self.gpu = gpu; self.template = template; self.imageURL = imageURL
        gridTexture = try WallpaperGridTexture(device: gpu.device)
        let scene = try shaders.scene(for: template.shader)
        surface = SurfaceConfiguration(pixelFormat: .bgra8Unorm, isOpaque: true, loadAction: .dontCare, maximumDimension: scene.nativeResolution ? nil : GPUTuning.maximumWallpaperDimension)
        usesLiveInputs = scene.liveInputs
        backdropKey = try gpu.libraries.unitKey(for: scene.module) + ":" + scene.fragment + ":" + WallpaperCoverStore.cacheKey(for: template)
        pipeline = try gpu.pipeline(scene.module, vertex: "wallpaperVertex", fragment: scene.fragment, color: .bgra8Unorm)
        emblem = try template.emblem.map { try WallpaperEmblemPipeline(placement: $0, canvas: template.canvasSize, gpu: gpu, assets: assets) }
        accent = Self.color(template.accent); background = Self.color(template.background)
        params = Self.parameters(scene.parameters, overrides: template.params ?? [:])
        let bundledImage = template.image.flatMap(assets.image)
        if let image = template.image, imageURL == nil, bundledImage == nil { throw WallpaperError.missingAsset(image) }
        if let url = imageURL ?? bundledImage {
            texture = try gpu.textures.newTexture(URL: url, options: [.SRGB: false, .textureUsage: MTLTextureUsage.shaderRead.rawValue])
        } else {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
            guard let fallback = gpu.device.makeTexture(descriptor: descriptor) else { throw WallpaperError.unavailable("Could not create a wallpaper texture.") }
            var pixel: UInt32 = 0xff101010
            fallback.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
            texture = fallback
        }
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, frame: WallpaperFrame) -> Bool {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        var uniforms = WallpaperUniforms(size: SIMD2(Float(size.width), Float(size.height)), time: Float(usesLiveInputs ? frame.time : frame.time.truncatingRemainder(dividingBy: 3600)),
            energy: Float(min(1, max(0, frame.energy))), accent: accent, background: background, channels: frame.channels, params: params,
            interaction: SIMD4(Float(frame.liveInputs.lidOpen), Float(frame.liveInputs.sound), Float(frame.liveInputs.pollen), Float(frame.liveInputs.charging)),
            environment: SIMD4(Float(frame.liveInputs.battery), Float(frame.liveInputs.daylight), frame.liveInputs.reducedMotion ? 1 : 0, Float(frame.liveInputs.externalPower)),
            motion: SIMD4(Float(frame.liveInputs.parallax.x), Float(frame.liveInputs.parallax.y), Float(frame.liveInputs.motionStir), frame.liveInputs.mirrored ? 1 : 0))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<WallpaperUniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(gridTexture.texture(for: frame.grid), index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        emblem?.encode(encoder, size: size)
        encoder.endEncoding()
        return true
    }
    func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, size: CGSize, time: Double, energy: Double,
                channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) -> Bool {
        encode(command: command, pass: pass, size: size, frame: WallpaperFrame(time: time, energy: energy, channels: channels, grid: grid))
    }
    /// Declared defaults, overridden by the template's `params`, clamped to each declaration's bounds.
    static func parameters(_ declared: [WallpaperSceneParameter], overrides: [String: Double]) -> (SIMD4<Float>, SIMD4<Float>) {
        var values = [Float](repeating: 0, count: 8)
        for (index, parameter) in declared.prefix(8).enumerated() {
            var value = overrides[parameter.key] ?? parameter.default
            if let minimum = parameter.minimum { value = max(minimum, value) }
            if let maximum = parameter.maximum { value = min(maximum, value) }
            values[index] = Float(value)
        }
        return (SIMD4(values[0], values[1], values[2], values[3]), SIMD4(values[4], values[5], values[6], values[7]))
    }
    private static func color(_ hex: UInt32) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 255) / 255, Float((hex >> 8) & 255) / 255, Float(hex & 255) / 255, 1)
    }
}
