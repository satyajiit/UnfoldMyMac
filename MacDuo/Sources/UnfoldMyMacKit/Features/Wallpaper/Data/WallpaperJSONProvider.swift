import Foundation
import UnfoldMyMacCore

/// A tool can atomically write this JSON snapshot without knowing anything about rendering.
actor WallpaperJSONProvider: WallpaperDataProvider {
    nonisolated let id = "tool"
    nonisolated let interval: TimeInterval = 1
    private let url: URL
    init(url: URL) { self.url = url }
    func sample(at date: Date) async throws -> WallpaperDataSample {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 65_537) ?? Data()
        guard data.count <= 65_536 else { throw WallpaperError.invalidData }
        let sample = try WallpaperSnapshotJSON.decode(data, namespace: id)
        guard WallpaperDataSample.freshness.contains(date.timeIntervalSince(sample.timestamp)) else {
            throw WallpaperError.unavailable("The tool connection is stale. Waiting for a new snapshot.")
        }
        return sample
    }
}
