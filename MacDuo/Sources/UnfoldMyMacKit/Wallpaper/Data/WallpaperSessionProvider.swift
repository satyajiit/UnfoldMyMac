import Foundation
import UnfoldMyMacCore

/// Playful counters describe this wallpaper session, never fabricated Grok account usage.
actor WallpaperSessionProvider: WallpaperDataProvider {
    nonisolated let id = "scene"
    nonisolated let interval: TimeInterval = 1
    private let started = ContinuousClock.now
    func sample(at date: Date) async throws -> WallpaperDataSample {
        let elapsed = max(0, Double(started.duration(to: .now).components.seconds))
        return .init(timestamp: date, numbers: ["scene.minutes": floor(elapsed / 60), "scene.remarks": floor(elapsed / 8) + 1,
            "scene.laps": floor(elapsed / 18),
            "scene.energy": 0.38 + 0.18 * sin(elapsed / 12)], text: ["scene.scope": "WALLPAPER SESSION · JUST FOR FUN"])
    }
}
