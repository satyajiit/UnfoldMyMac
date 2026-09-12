import AppKit

/// Cover art for the gallery and the still handed to the system wallpaper sampler.
@MainActor enum WallpaperCoverRenderer {
    static func cover(pipeline: WallpaperPipeline) throws -> NSImage {
        if let name = pipeline.template.coverImage, let url = BundleResources.wallpaperCover(name), let image = NSImage(contentsOf: url) { return image }
        return try image(pipeline: pipeline)
    }
    static func image(pipeline: WallpaperPipeline, size: CGSize = CGSize(width: 640, height: 400)) throws -> NSImage {
        try OffscreenRenderer.image(pipeline, frame: .cover, size: size)
    }
}
