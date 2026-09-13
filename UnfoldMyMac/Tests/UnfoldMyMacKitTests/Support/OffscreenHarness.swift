import AppKit
import CryptoKit
import Metal
import Testing

/// Renders one frame into a shared texture and hands back its bytes.
/// Every pipeline family has the same shape: create a target, build a pass, encode, wait, read back.
@MainActor enum OffscreenHarness {
    struct Frame {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let gpuSeconds: Double
        var sha256: String { SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined() }
    }

    static func render(device: MTLDevice, queue: MTLCommandQueue, pixelFormat: MTLPixelFormat, width: Int, height: Int,
                       encode: (MTLCommandBuffer, MTLRenderPassDescriptor) -> Bool) throws -> Frame {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        let command = try #require(queue.makeCommandBuffer())
        #expect(encode(command, pass))
        command.commit()
        command.waitUntilCompleted()
        #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return Frame(pixels: pixels, width: width, height: height, gpuSeconds: max(0, command.gpuEndTime - command.gpuStartTime))
    }

    /// A deterministic multicolour source image for capture-fed pipelines.
    static func gradient(width: Int, height: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8(x % 256)
                bytes[i + 1] = UInt8(y % 256)
                bytes[i + 2] = UInt8((x + y) % 256)
            }
        }
        return bytes
    }
}
