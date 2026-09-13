import Foundation
import UnfoldMyMacCore

/// Interpolates 30 Hz input at display cadence. Pulse ages advance between samples, without replaying events.
struct WallpaperLiveInputSmoother: Equatable, Sendable {
    private var value = WallpaperLiveInputs()
    private var previous = WallpaperLiveInputs()
    mutating func advance(toward target: WallpaperLiveInputs, delta: Double, animating: Bool) -> WallpaperLiveInputs {
        let dt = min(0.1, max(0, delta))
        if animating {
            value.lidOpen += (target.lidOpen-value.lidOpen) * (1-exp(-dt*5))
            value.sound += (target.sound-value.sound) * (1-exp(-dt*12))
            value.battery += (target.battery-value.battery) * (1-exp(-dt*0.5))
            value.externalPower += (WallpaperLiveInputs.unit(target.externalPower)-value.externalPower) * (1-exp(-dt*2))
            value.daylight += (target.daylight-value.daylight) * (1-exp(-dt*0.1))
            for axis in 0..<2 {
                let position = target.parallax[axis].isFinite ? min(1.5, max(-1.5, target.parallax[axis])) : 0
                value.parallax[axis] += (position-value.parallax[axis]) * (1-exp(-dt*3.5))
            }
            value.motionStir += (WallpaperLiveInputs.unit(target.motionStir)-value.motionStir) * (1-exp(-dt*6))
            value.pollen = Self.age(target.pollen, previous: previous.pollen, current: value.pollen, delta: dt)
            value.charging = Self.age(target.charging, previous: previous.charging, current: value.charging, delta: dt)
        } else {
            value = target; value.lidOpen = 1; value.sound = 0
            value.pollen = -1; value.charging = -1
            value.parallax = .zero; value.motionStir = 0
        }
        value.reducedMotion = !animating
        previous = target
        return value
    }
    private static func age(_ target: Double, previous: Double, current: Double, delta: Double) -> Double {
        guard target >= 0 else { return -1 }
        guard previous >= 0, target >= previous else { return target }
        return min(target+1.0/30, max(target,current+delta))
    }
}
