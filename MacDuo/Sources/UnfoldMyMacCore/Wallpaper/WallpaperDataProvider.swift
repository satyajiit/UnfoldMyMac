import Foundation

/// Providers own I/O. Renderers receive immutable, namespaced values only.
public protocol WallpaperDataProvider: Sendable {
    var id: String { get }
    var interval: TimeInterval { get }
    func sample(at date: Date) async throws -> WallpaperDataSample
}
