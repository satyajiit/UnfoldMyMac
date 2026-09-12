import Foundation
import UnfoldMyMacCore

/// Eases energy and channels toward their targets so data changes never pop, and advances scene time
/// only while animating. Pure; the display-link driver feeds it elapsed seconds.
struct WallpaperFrameSmoother: Equatable, Sendable {
    static let rate = 4.0
    var targetEnergy = 0.0
    var targetChannels = SIMD4<Float>.zero
    var grid: WallpaperScalarGrid?
    private var energy = 0.0
    private var channels = SIMD4<Float>.zero
    private var time = 0.0

    mutating func setTargets(energy: Double, channels: SIMD4<Float>, grid: WallpaperScalarGrid?) {
        targetEnergy = energy.isFinite ? min(1, max(0, energy)) : 0
        targetChannels = channels
        self.grid = grid
    }
    mutating func advance(delta: Double, animating: Bool) -> WallpaperFrame {
        if animating {
            let blend = 1 - exp(-delta * Self.rate)
            time += delta
            energy += (targetEnergy - energy) * blend
            channels += (targetChannels - channels) * Float(blend)
        } else {
            energy = targetEnergy; channels = targetChannels
        }
        return WallpaperFrame(time: animating ? time : 0, energy: energy, channels: channels, grid: grid)
    }
}
