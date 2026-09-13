import Metal
import UnfoldMyMacCore

/// A separate pass preserves the original asset's colors, proportions and silhouette.
/// It cannot be replaced by the personal-background setting.
@MainActor final class WallpaperEmblemPipeline {
    let placement: WallpaperEmblem
    let canvas: WallpaperCanvas
    private let texture: MTLTexture
    private let pipeline: MTLRenderPipelineState

    init(placement: WallpaperEmblem, canvas: WallpaperCanvas = .standard, gpu: GPUContext, assets: WallpaperAssetResolver = .shared) throws {
        guard placement.isValid else { throw WallpaperError.invalidField("emblem") }
        guard let url = assets.mark(placement.asset) else { throw WallpaperError.missingAsset(placement.asset) }
        self.placement = placement; self.canvas = canvas
        do { texture = try TextureLoader.premultiplied(url, device: gpu.device) } catch { throw WallpaperError.invalidData }
        let aspect = canvas.width / canvas.height
        guard placement.y + placement.width * aspect * Double(texture.height) / Double(texture.width) <= 1 else {
            throw WallpaperError.invalidField("emblem")
        }
        pipeline = try gpu.pipeline(.wallpaperEmblem, vertex: "wallpaperVertex", fragment: "emblemFragment", color: .bgra8Unorm, blend: .premultiplied)
    }
    func encode(_ encoder: MTLRenderCommandEncoder, size: CGSize) {
        let fit = canvas.fit(width: size.width, height: size.height)
        let width = placement.width * fit.width
        encoder.setViewport(MTLViewport(originX: (size.width - fit.width) / 2 + placement.x * fit.width,
            originY: (size.height - fit.height) / 2 + placement.y * fit.height,
            width: width, height: width * Double(texture.height) / Double(texture.width), znear: 0, zfar: 1))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
