import MetalKit
import UnfoldMyMacCore

private struct WallpaperUniforms {
    var size: SIMD2<Float>
    var time: Float
    var energy: Float
    var accent: SIMD4<Float>
    var background: SIMD4<Float>
    var channels: SIMD4<Float>
}

@MainActor final class WallpaperPipeline {
    let catalog: WallpaperShaderCatalog
    let template: WallpaperTemplate
    /// The personal background this pipeline was built with, if any; part of its identity for caches.
    let imageURL: URL?
    private let pipeline: MTLRenderPipelineState
    private let texture: MTLTexture
    private let emblem: WallpaperEmblemPipeline?
    private let gridTexture: WallpaperGridTexture
    init(template: WallpaperTemplate, catalog: WallpaperShaderCatalog, imageURL: URL? = nil) throws {
        self.catalog = catalog; self.template = template; self.imageURL = imageURL
        gridTexture = try WallpaperGridTexture(device: catalog.gpu)
        pipeline = try catalog.pipeline(for: template.shader)
        emblem = try template.emblem.map { try WallpaperEmblemPipeline(placement: $0, catalog: catalog) }
        let bundledImage = template.image.flatMap { BundleResources.artwork($0) }
        if let image = template.image, imageURL == nil, bundledImage == nil { throw WallpaperError.unavailable("The template’s artwork ‘\(image)’ is not installed.") }
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
