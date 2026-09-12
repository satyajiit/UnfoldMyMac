import Metal
import UnfoldMyMacCore

private struct WallpaperUniforms {
    var size: SIMD2<Float>
    var time: Float
    var energy: Float
    var accent: SIMD4<Float>
    var background: SIMD4<Float>
    var channels: SIMD4<Float>
}

/// One template's scene shader, artwork texture, data grid and optional emblem pass.
@MainActor final class WallpaperPipeline: MetalPipeline {
    let gpu: GPUContext
    let template: WallpaperTemplate
    /// The personal background this pipeline was built with, if any; part of its identity for caches.
    let imageURL: URL?
    let surface = SurfaceConfiguration(pixelFormat: .bgra8Unorm, isOpaque: true, loadAction: .dontCare, maximumDimension: GPUTuning.maximumWallpaperDimension)
    private let pipeline: MTLRenderPipelineState
    private let texture: MTLTexture
    private let emblem: WallpaperEmblemPipeline?
    private let gridTexture: WallpaperGridTexture
    private let accent: SIMD4<Float>
    private let background: SIMD4<Float>

    init(template: WallpaperTemplate, gpu: GPUContext, shaders: WallpaperShaderCatalog, imageURL: URL? = nil) throws {
        self.gpu = gpu; self.template = template; self.imageURL = imageURL
        gridTexture = try WallpaperGridTexture(device: gpu.device)
        let shader = try shaders.shader(for: template.shader)
        pipeline = try gpu.pipeline(try shaders.module(for: template.shader), vertex: "wallpaperVertex", fragment: shader.fragment, color: .bgra8Unorm)
        emblem = try template.emblem.map { try WallpaperEmblemPipeline(placement: $0, gpu: gpu) }
        accent = Self.color(template.accent); background = Self.color(template.background)
        let bundledImage = template.image.flatMap { BundleResources.artwork($0) }
        if let image = template.image, imageURL == nil, bundledImage == nil { throw WallpaperError.unavailable("The template’s artwork ‘\(image)’ is not installed.") }
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
        var uniforms = WallpaperUniforms(size: SIMD2(Float(size.width), Float(size.height)), time: Float(frame.time.truncatingRemainder(dividingBy: 3600)),
            energy: Float(min(1, max(0, frame.energy))), accent: accent, background: background, channels: frame.channels)
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
    private static func color(_ hex: UInt32) -> SIMD4<Float> {
        SIMD4(Float((hex >> 16) & 255) / 255, Float((hex >> 8) & 255) / 255, Float(hex & 255) / 255, 1)
    }
}
