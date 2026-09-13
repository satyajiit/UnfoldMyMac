import Foundation

/// Deterministic event/envelope processing, sampled independently of rendering.
public struct WallpaperInputDynamics: Sendable {
    public private(set) var value = WallpaperLiveInputs()
    private var lastTime: Double?
    private var lastPower: Bool?
    private var lastPuff = -Double.infinity
    private var peakArmed = true
    public init() {}

    public mutating func sample(now: Double, lidAngle: Double?, rms: Double, sensitivity: Double,
                                battery: Double?, pluggedIn: Bool?, daylight: Double,
                                soundEnabled: Bool, reducedMotion: Bool) {
        let delta = min(0.1, max(0, now - (lastTime ?? now)))
        lastTime = now
        value.lidOpen = WallpaperLiveInputs.openness(angle: lidAngle)
        value.battery = WallpaperLiveInputs.unit(battery ?? 0.65, fallback: 0.65)
        value.daylight = WallpaperLiveInputs.unit(daylight, fallback: 0.35)
        value.reducedMotion = reducedMotion
        if let pluggedIn { value.externalPower = pluggedIn ? 1 : 0 }
        let gain = sensitivity.isFinite ? min(4, max(0.25, sensitivity)) : 1
        let amplitude = soundEnabled && !reducedMotion ? WallpaperLiveInputs.unit((rms - 0.003) * 18 * gain) : 0
        value.sound += (amplitude - value.sound) * (1 - exp(-delta * (amplitude > value.sound ? 18 : 3)))
        advanceEvents(now: now, delta: delta, amplitude: amplitude, pluggedIn: pluggedIn, reducedMotion: reducedMotion)
        if !soundEnabled || reducedMotion { value.sound = 0; value.pollen = -1 }
    }
    private mutating func advanceEvents(now: Double, delta: Double, amplitude: Double, pluggedIn: Bool?, reducedMotion: Bool) {
        if amplitude < 0.25 { peakArmed = true }
        if value.pollen >= 0 { value.pollen += delta; if value.pollen > 3 { value.pollen = -1 } }
        if peakArmed && amplitude > 0.65 && now - lastPuff >= 3 {
            value.pollen = 0; lastPuff = now; peakArmed = false
        }
        if value.charging >= 0 { value.charging += delta; if value.charging > 9 { value.charging = -1 } }
        if let pluggedIn {
            if lastPower == false && pluggedIn && !reducedMotion { value.charging = 0 }
            lastPower = pluggedIn
        }
        if reducedMotion { value.charging = -1 }
    }

    public mutating func suspend() {
        lastTime = nil; lastPower = nil; lastPuff = -.infinity; peakArmed = true
        value = .init()
    }
}
