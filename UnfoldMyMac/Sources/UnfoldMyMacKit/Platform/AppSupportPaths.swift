import Foundation

/// App-owned folders under Application Support. The legacy pre-rename folder is moved once, explicitly,
/// from the composition root rather than as a side effect of a default argument.
enum AppSupportPaths {
    static let root = URL.applicationSupportDirectory.appendingPathComponent("UnfoldMyMac", isDirectory: true)
    static let artwork = root.appendingPathComponent("Artwork", isDirectory: true)
    static let wallpaper = root.appendingPathComponent("Wallpaper", isDirectory: true)
    static let legacyArtwork = URL.applicationSupportDirectory.appendingPathComponent("Luma/Artwork", isDirectory: true)

    static func migrateLegacyArtwork(fileManager: FileManager = .default) {
        guard !fileManager.fileExists(atPath: artwork.path), fileManager.fileExists(atPath: legacyArtwork.path) else { return }
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try fileManager.moveItem(at: legacyArtwork, to: artwork)
            let parent = legacyArtwork.deletingLastPathComponent()
            if let items = try? fileManager.contentsOfDirectory(atPath: parent.path), items.isEmpty { try? fileManager.removeItem(at: parent) }
        } catch {}
    }
}
