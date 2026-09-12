import Foundation

/// Providers own I/O. Renderers receive immutable, namespaced values only.
public protocol WallpaperDataProvider: Sendable {
    var id: String { get }
    var interval: TimeInterval { get }
    /// Distinguishes two providers of one namespace built from different configuration (another
    /// username, folder or URL). The data hub restarts sampling when it changes and keeps it otherwise.
    var fingerprint: String { get }
    func sample(at date: Date) async throws -> WallpaperDataSample
}

public extension WallpaperDataProvider {
    var fingerprint: String { "" }
}
