import Foundation
import UnfoldMyMacCore

struct StorageWallpaperProvider: WallpaperDataProvider {
    let id = "storage"
    let interval: TimeInterval = 5
    func sample(at date: Date) async throws -> WallpaperDataSample {
        let values = try URL.homeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
        guard let free = values.volumeAvailableCapacity, let total = values.volumeTotalCapacity, total > 0 else {
            throw WallpaperError.unavailable("Storage information unavailable")
        }
        return Self.snapshot(free: Int64(free), total: Int64(total), at: date)
    }
    static func snapshot(free: Int64, total: Int64, at date: Date) -> WallpaperDataSample {
        guard total > 0, free >= 0, free <= total else { return .init(timestamp: date) }
        let fraction = Double(free) / Double(total)
        return .init(timestamp: date, numbers: ["storage.free": fraction, "storage.used": 1 - fraction],
            text: ["storage.capacity": ByteCountFormatter.string(fromByteCount: free, countStyle: .file) + " FREE",
                   "storage.state": fraction < 0.1 ? "INVENTORY ALMOST FULL" : "ROOM FOR MORE LOOT",
                   "storage.detail": fraction < 0.1 ? "Clear space on your home volume before your next install." : "Home volume · " + ByteCountFormatter.string(fromByteCount: total, countStyle: .file) + " total"])
    }
}
