import IOSurface
import Metal
import QuartzCore

/// The still the host asks for, rendered by the same Metal pipeline that draws the live scene.
///
/// `WallpaperAgent` pipes this to `wallpaperexportd`, which writes it to `/var/db/Wallpapers/<uuid>/` for
/// the login window and for the System Settings thumbnail. A nil snapshot is not cosmetic: it shows as a
/// grey lock screen. The surface must be IOSurface-backed because the reply crosses a process boundary —
/// a `CGImage` snapshot marshals to nothing.
@MainActor enum WallpaperProviderSnapshot {
    /// 'BGRA' — the IOSurface four-char code matching `SurfaceConfiguration.pixelFormat`'s `.bgra8Unorm`.
    private static let bgra: Int = 0x4247_5241

    /// Renders `frame` at the destination's pixel size straight into an IOSurface-backed texture. No CPU
    /// readback: the GPU writes the shared surface the host will map, which is the whole point of the format.
    static func surface(pipeline: WallpaperPipeline, frame: WallpaperFrame, size: CGSize, scale: CGFloat) -> IOSurfaceRef? {
        let pixels = MetalSurfaceRenderer<WallpaperPipeline>.drawableSize(points: size, scale: scale, cap: pipeline.surface.maximumDimension)
        let width = Int(pixels.width), height = Int(pixels.height)
        guard width > 0, height > 0 else { return nil }
        let properties: [IOSurfacePropertyKey: any Sendable] = [
            .width: width, .height: height, .bytesPerElement: 4, .pixelFormat: bgra,
        ]
        guard let surface = IOSurface(properties: properties) else {
            WallpaperProviderLog.fault("snapshot IOSurface allocation failed \(width)x\(height)")
            return nil
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pipeline.surface.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = pipeline.gpu.device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0),
              let command = pipeline.gpu.queue.makeCommandBuffer() else {
            WallpaperProviderLog.fault("snapshot texture allocation failed")
            return nil
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = pipeline.surface.clearColor
        guard pipeline.encode(command: command, pass: pass, size: pixels, frame: frame) else {
            WallpaperProviderLog.fault("snapshot encode declined for \(pipeline.template.id)")
            return nil
        }
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error {
            WallpaperProviderLog.fault("snapshot GPU error \(error.localizedDescription)")
            return nil
        }
        return unsafeBitCast(surface, to: IOSurfaceRef.self)
    }

}
