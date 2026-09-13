import AppKit

/// Decoded cover thumbnails shared by every tile and inspector. Bounded, main-actor and injected through the
/// SwiftUI environment, so views never reach for a global cache.
@MainActor final class CoverImageStore {
    /// The environment default; the app root injects its own instance.
    static let fallback = CoverImageStore()
    private let images = NSCache<NSURL, NSImage>()
    private let maxPixelSize: Int

    init(countLimit: Int = 80, maxPixelSize: Int = 720) {
        images.countLimit = countLimit
        self.maxPixelSize = maxPixelSize
    }
    func cached(_ url: URL) -> NSImage? { images.object(forKey: url as NSURL) }
    /// Decodes off the main actor the first time, then serves the cached image.
    func image(for url: URL) async -> NSImage? {
        if let cached = cached(url) { return cached }
        let size = maxPixelSize
        guard let thumbnail = await Task.detached(priority: .utility) { ImageFiles.thumbnail(at: url, maxPixelSize: size) }.value else { return nil }
        let image = NSImage(cgImage: thumbnail, size: .zero)
        images.setObject(image, forKey: url as NSURL)
        return image
    }
}
