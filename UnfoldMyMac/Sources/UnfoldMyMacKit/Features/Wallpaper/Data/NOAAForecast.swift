import Foundation
import CryptoKit
import UnfoldMyMacCore

struct NOAAForecast: Sendable {
    let observation: Date
    let forecast: Date
    let grid: WallpaperScalarGrid
}
