import Foundation
import UnfoldMyMacCore

struct CountdownWallpaperProvider: WallpaperDataProvider {
    let id = "countdown"
    let interval: TimeInterval = 5
    let countdown: WallpaperCountdown
    var fingerprint: String { "\(countdown.year)-\(countdown.month)-\(countdown.day)" }
    func sample(at date: Date) async throws -> WallpaperDataSample { countdown.sample(at: date) }
}
