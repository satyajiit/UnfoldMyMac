import MetalKit
import ImageIO
import UnfoldMyMacCore

/// A separate pass preserves the original asset's colors, proportions and silhouette.
/// It cannot be replaced by the personal-background setting.
@MainActor final class WallpaperEmblemPipeline {
    let placement: WallpaperEmblem
    private let texture: MTLTexture
    private let pipeline: MTLRenderPipelineState

    static func url(_ asset: String) -> URL? {
        Bundle.module.url(forResource: asset, withExtension: "png", subdirectory: "Resources/WallpaperMarks")
    }
    init(placement: WallpaperEmblem, catalog: WallpaperShaderCatalog) throws {
        guard placement.isValid, let url = Self.url(placement.asset) else {
            throw WallpaperError.unavailable("The original logo ‘\(placement.asset)’ is not installed.")
        }
        self.placement = placement
        texture = try Self.loadPremultiplied(url, device: catalog.gpu)
        guard placement.y + placement.width * 1.6 * Double(texture.height) / Double(texture.width) <= 1 else {
            throw WallpaperError.invalidTemplate
        }
        let library = try catalog.library(resource: "Emblem")
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "wallpaperVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "emblemFragment")
        let color = descriptor.colorAttachments[0]!
        color.pixelFormat = .bgra8Unorm; color.isBlendingEnabled = true
        color.sourceRGBBlendFactor = .one; color.destinationRGBBlendFactor = .oneMinusSourceAlpha
        color.sourceAlphaBlendFactor = .one; color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try catalog.gpu.makeRenderPipelineState(descriptor: descriptor)
    }
    /// Indexed PNGs can carry RGB in fully transparent palette entries. Normalize explicitly
    /// instead of relying on MTKTextureLoader to supply premultiplied pixels for every PNG type.
    private static func loadPremultiplied(_ url: URL, device: MTLDevice) throws -> MTLTexture {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width <= 4096, image.height <= 4096,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
              let bytes = context.data else { throw WallpaperError.invalidData }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: image.width, height: image.height, mipmapped: false)
        descriptor.usage = .shaderRead; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw WallpaperError.invalidData }
        texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0,
                        withBytes: bytes, bytesPerRow: image.width * 4)
        return texture
    }
    func encode(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        let scale = min(size.width / 1600, size.height / 1000)
        let width = placement.width * 1600 * scale
        encoder.setViewport(MTLViewport(originX: (size.width - 1600 * scale) / 2 + placement.x * 1600 * scale,
            originY: (size.height - 1000 * scale) / 2 + placement.y * 1000 * scale,
            width: width, height: width * Double(texture.height) / Double(texture.width), znear: 0, zfar: 1))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
