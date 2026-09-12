import CoreGraphics
import ImageIO
import Metal

/// Image decoding paths that `MTKTextureLoader` does not cover exactly.
enum TextureLoader {
    /// Indexed PNGs can carry RGB in fully transparent palette entries. Normalize explicitly
    /// instead of relying on MTKTextureLoader to supply premultiplied pixels for every PNG type.
    static func premultiplied(_ url: URL, device: MTLDevice, maximumEdge: Int = 4096) throws -> MTLTexture {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width <= maximumEdge, image.height <= maximumEdge,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
              let bytes = context.data else { throw GPUError.allocationFailed("the image ‘\(url.lastPathComponent)’") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: image.width, height: image.height, mipmapped: false)
        descriptor.usage = .shaderRead; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw GPUError.allocationFailed("a texture for ‘\(url.lastPathComponent)’") }
        texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: image.width * 4)
        return texture
    }
}
