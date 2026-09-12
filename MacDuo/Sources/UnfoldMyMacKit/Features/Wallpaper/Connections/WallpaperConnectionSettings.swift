import Foundation
import Observation
import UnfoldMyMacCore

struct WallpaperConnectionSettings: Codable, Equatable, Sendable {
    var enabled = false
    var username: String?
    var path: String?
}
