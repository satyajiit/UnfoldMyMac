import Metal
import UnfoldMyMacCore

/// A separate pass preserves the original asset's colors, proportions and silhouette.
/// It cannot be replaced by the personal-background setting.
@MainActor final class WallpaperEmblemPipeline {
    let placement: WallpaperEmblem
    private let texture: MTLTexture
    private let pipeline: MTLRenderPipelineState

    static func url(_ asset: String) -> URL? { BundleResources.wallpaperMark(asset) }

    init(placement: WallpaperEmblem, gpu: GPUContext) throws {
        guard placement.isValid, let url = Self.url(placement.asset) else {
            throw WallpaperError.unavailable("The original logo ‘\(placement.asset)’ is not installed.")
        }
        self.placement = placement
        do { texture = try TextureLoader.premultiplied(url, device: gpu.device) } catch { throw WallpaperError.invalidData }
        guard placement.y + placement.width * 1.6 * Double(texture.height) / Double(texture.width) <= 1 else {
            throw WallpaperError.invalidTemplate
        }
        pipeline = try gpu.pipeline(.wallpaperEmblem, vertex: "wallpaperVertex", fragment: "emblemFragment", color: .bgra8Unorm, blend: .premultiplied)
    }
    func encode(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        let scale = min(size.width / WallpaperCanvas.width, size.height / WallpaperCanvas.height)
        let width = placement.width * WallpaperCanvas.width * scale
        encoder.setViewport(MTLViewport(originX: (size.width - WallpaperCanvas.width * scale) / 2 + placement.x * WallpaperCanvas.width * scale,
            originY: (size.height - WallpaperCanvas.height * scale) / 2 + placement.y * WallpaperCanvas.height * scale,
            width: width, height: width * Double(texture.height) / Double(texture.width), znear: 0, zfar: 1))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
