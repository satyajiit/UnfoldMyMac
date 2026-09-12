import AppKit
import CryptoKit
import Metal

struct OffscreenFrame {
    let pixels: [UInt8]
    let width: Int
    let height: Int
    let gpuSeconds: Double
    var sha256: String { SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined() }
}

/// Renders one frame of any pipeline into a shared texture and reads it back: covers, stills and checks.
@MainActor enum OffscreenRenderer {
    static func render<P: MetalPipeline>(_ pipeline: P, frame: P.Frame, width: Int, height: Int) throws -> OffscreenFrame {
        let surface = pipeline.surface
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: surface.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = pipeline.gpu.device.makeTexture(descriptor: descriptor) else { throw GPUError.allocationFailed("the offscreen surface") }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = surface.clearColor
        guard let command = pipeline.gpu.queue.makeCommandBuffer() else { throw GPUError.allocationFailed("the offscreen command buffer") }
        guard pipeline.encode(command: command, pass: pass, size: CGSize(width: width, height: height), frame: frame) else {
            throw GPUError.allocationFailed("the offscreen encoder")
        }
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return OffscreenFrame(pixels: pixels, width: width, height: height, gpuSeconds: max(0, command.gpuEndTime - command.gpuStartTime))
    }
    /// A still at `size` points, honouring the pipeline's drawable cap.
    static func image<P: MetalPipeline>(_ pipeline: P, frame: P.Frame, size: CGSize) throws -> NSImage {
        let pixels = MetalSurfaceRenderer<P>.drawableSize(points: size, scale: 1, cap: pipeline.surface.maximumDimension)
        let rendered = try render(pipeline, frame: frame, width: Int(pixels.width), height: Int(pixels.height))
        return NSImage(cgImage: try cgImage(rendered), size: NSSize(width: rendered.width, height: rendered.height))
    }
    static func cgImage(_ frame: OffscreenFrame) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(frame.pixels) as CFData), let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.width * 4,
                space: space, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw GPUError.allocationFailed("the offscreen image") }
        return image
    }
}
