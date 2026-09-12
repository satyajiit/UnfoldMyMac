import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Copies a user's image into the wallpaper folder as the shared custom background, downsampled to at most
/// 2560 px and re-encoded as PNG so every image-based scene reads one known format.
enum WallpaperBackgroundImporter {
    static let maximumPixelSize = 2560

    static func save(_ url: URL) async throws {
        let data = try await Task.detached(priority: .userInitiated) { try encode(url) }.value
        try FileManager.default.createDirectory(at: WallpaperPaths.root, withIntermediateDirectories: true)
        try data.write(to: WallpaperPaths.background, options: .atomic)
    }
    private nonisolated static func encode(_ url: URL) throws -> Data {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw CocoaError(.fileReadCorruptFile) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }
}
