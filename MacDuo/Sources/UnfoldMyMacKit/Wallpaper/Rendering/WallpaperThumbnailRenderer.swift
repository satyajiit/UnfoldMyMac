import AppKit
import Metal

@MainActor enum WallpaperThumbnailRenderer {
    static func cover(pipeline: WallpaperPipeline) throws -> NSImage {
        if let name = pipeline.template.coverImage,
           let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/WallpaperCovers"),
           let image = NSImage(contentsOf: url) { return image }
        return try image(pipeline: pipeline)
    }
    static func image(pipeline: WallpaperPipeline, size: CGSize = CGSize(width: 640, height: 400)) throws -> NSImage {
        let scale = min(1, 1920 / max(1, max(size.width, size.height)))
        let width = max(1, Int((size.width * scale).rounded())), height = max(1, Int((size.height * scale).rounded()))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]; descriptor.storageMode = .shared
        guard let texture = pipeline.catalog.gpu.makeTexture(descriptor: descriptor),
              let command = pipeline.catalog.queue.makeCommandBuffer() else { throw CocoaError(.coderInvalidValue) }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        guard pipeline.encode(command: command, pass: pass, size: CGSize(width: width, height: height), time: 4, energy: 0.35) else { throw CocoaError(.coderInvalidValue) }
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0) }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData), let color = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width*4,
                space: color, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw CocoaError(.coderInvalidValue) }
        return NSImage(cgImage: image, size: NSSize(width: width, height: height))
    }
}
