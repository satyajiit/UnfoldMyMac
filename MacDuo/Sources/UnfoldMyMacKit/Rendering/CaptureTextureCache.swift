import CoreVideo
import Metal

/// A capture buffer and the Metal texture wrapping it; both must outlive the command buffer that samples it.
final class CapturedTexture: @unchecked Sendable {
    let frame: DesktopFrame
    let wrapped: CVMetalTexture
    let texture: MTLTexture
    init(frame: DesktopFrame, wrapped: CVMetalTexture, texture: MTLTexture) { self.frame = frame; self.wrapped = wrapped; self.texture = texture }
}

/// Wraps `CVPixelBuffer`s as textures without copies. Flushed whenever the display size changes or the
/// effect stops, so retired buffers do not accumulate (L7).
@MainActor final class CaptureTextureCache {
    private var cache: CVMetalTextureCache?
    init(device: MTLDevice) { CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) }
    func texture(for frame: DesktopFrame, pixelFormat: MTLPixelFormat) -> CapturedTexture? {
        guard let cache else { return nil }
        var wrapped: CVMetalTexture?
        let buffer = frame.buffer
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, pixelFormat,
            CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &wrapped)
        guard status == kCVReturnSuccess, let wrapped, let texture = CVMetalTextureGetTexture(wrapped) else { return nil }
        return CapturedTexture(frame: frame, wrapped: wrapped, texture: texture)
    }
    func flush() { if let cache { CVMetalTextureCacheFlush(cache, 0) } }
}
