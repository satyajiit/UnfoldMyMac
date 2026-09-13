import Foundation
import Observation
import UnfoldMyMacCore

struct WallpaperConnectionSettings: Codable, Equatable, Sendable {
    var enabled = false
    var username: String?
    var path: String?
    var sensitivity: Double?
    var parallax: Bool?
    var motionSensors: Bool?
    var oneLiners: Bool?
    var lineInterval: Double?
    var blowToChange: Bool?
    var folderBookmark: Data?
    var liveCounts: Bool?
    var mirrored: Bool?
    var weatherLocation: WallpaperWeatherLocation?
    var sessionMinutes: Double?
    var sessionRestart: String?
    func restMinutes(default fallback: Double) -> Double {
        guard let sessionMinutes, sessionMinutes.isFinite else { return fallback }
        return min(60, max(1, sessionMinutes))
    }
    var showsLiveCounts: Bool { liveCounts ?? true }
    var showsWorkshopLines: Bool { oneLiners ?? true }
    var mirrorsComposition: Bool { mirrored ?? false }
    var pointerParallax: Bool { parallax ?? true }
    var sensorMotion: Bool { motionSensors ?? true }
    var showsOneLiners: Bool { oneLiners ?? false }
    var changesLineOnBlow: Bool { blowToChange ?? true }
    var rotationInterval: Double {
        guard let lineInterval, lineInterval.isFinite else { return 45 }
        return min(120, max(15, lineInterval))
    }
    var soundSensitivity: Double {
        guard let sensitivity, sensitivity.isFinite else { return 1 }
        return min(4, max(0.25, sensitivity))
    }
}
