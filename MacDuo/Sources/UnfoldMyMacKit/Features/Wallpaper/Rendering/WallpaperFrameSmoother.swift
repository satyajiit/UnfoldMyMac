import Foundation
import UnfoldMyMacCore

/// Eases energy and channels toward their targets so data changes never pop, and advances scene time only
/// while animating. Rates come from the template; a still scene holds the template's Reduce Motion time. Pure.
struct WallpaperFrameSmoother: Equatable, Sendable {
    let rate: Double
    let channelRates: SIMD4<Double>
    let stillTime: Double
    var targetEnergy = 0.0
    var targetChannels = SIMD4<Float>.zero
    var grid: WallpaperScalarGrid?
    private var energy = 0.0
    private var channels = SIMD4<Float>.zero
    private var time = 0.0

    init(rate: Double = 4, channelRates: SIMD4<Double>? = nil, stillTime: Double = 0) {
        self.rate = rate; self.channelRates = channelRates ?? SIMD4(repeating: rate); self.stillTime = stillTime
    }
    init(template: WallpaperTemplate) {
        var rates = SIMD4<Double>(repeating: template.smoothingRate)
        for (index, channel) in (template.channels ?? []).prefix(4).enumerated() { rates[index] = channel.smoothing ?? template.smoothingRate }
        self.init(rate: template.smoothingRate, channelRates: rates, stillTime: template.stillPose.time)
    }
    mutating func setTargets(energy: Double, channels: SIMD4<Float>, grid: WallpaperScalarGrid?) {
        targetEnergy = energy.isFinite ? min(1, max(0, energy)) : 0
        targetChannels = channels
        self.grid = grid
    }
    mutating func advance(delta: Double, animating: Bool) -> WallpaperFrame {
        if animating {
            time += delta
            energy += (targetEnergy - energy) * (1 - exp(-delta * rate))
            for lane in 0..<4 { channels[lane] += (targetChannels[lane] - channels[lane]) * Float(1 - exp(-delta * channelRates[lane])) }
        } else {
            energy = targetEnergy; channels = targetChannels
        }
        return WallpaperFrame(time: animating ? time : stillTime, energy: energy, channels: channels, grid: grid)
    }
}
