import Foundation
import UnfoldMyMacCore

/// The app is intentionally outside App Sandbox. Open-panel consent is remembered by macOS;
/// a bookmark follows the selected directory without silently falling back to an unapproved path.
enum WorkshopFolderAccess {
    static func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ bookmark: Data) throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                       relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    /// Shallow enumeration: packages, aliases, links and directories each occupy one shelf slot.
    static func count(at url: URL) throws -> Int {
        try Task.checkCancellation()
        let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isHiddenKey], options: [.skipsHiddenFiles])
        var count = 0
        for entry in entries {
            try Task.checkCancellation()
            if try entry.resourceValues(forKeys: [.isHiddenKey]).isHidden != true { count += 1 }
        }
        return count
    }
}

actor DesktopItemsWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "desktop"
    nonisolated let interval: TimeInterval = 5
    nonisolated let fingerprint: String
    private let bookmark: Data

    init(bookmark: Data) {
        self.bookmark = bookmark
        fingerprint = bookmark.base64EncodedString()
    }

    func sample(at date: Date) async throws -> WallpaperDataSample {
        try Task.checkCancellation()
        do {
            let folder = try WorkshopFolderAccess.resolve(bookmark)
            let count = try WorkshopFolderAccess.count(at: folder)
            return .init(timestamp: date, numbers: ["desktop.items": Double(count), "desktop.available": 1])
        } catch is CancellationError { throw CancellationError() }
        catch { throw WallpaperError.unavailable("Folder count unavailable. Choose the folder again in Customize to reconnect its shelves.") }
    }
}
