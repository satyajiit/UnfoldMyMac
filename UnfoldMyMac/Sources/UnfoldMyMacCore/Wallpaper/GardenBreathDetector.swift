import Foundation

/// A sustained envelope gesture, not speech recognition. Short clicks cannot turn the page.
public struct GardenBreathDetector: Sendable {
    private var held = 0.0
    private var quiet = 0.0
    private var cooldown = 0.0
    private var armed = true
    public init() {}
    public mutating func sample(amplitude: Double, delta: Double, enabled: Bool) -> Bool {
        guard enabled else { self = .init(); return false }
        let dt = min(0.1, max(0, delta))
        cooldown = max(0, cooldown-dt)
        if amplitude < 0.2 {
            quiet += dt; held = 0
            if quiet >= 0.4 { armed = true }
        } else {
            quiet = 0
            held = amplitude > 0.48 ? held+dt : max(0, held-dt)
        }
        guard armed, held >= 0.45, cooldown == 0 else { return false }
        armed = false; cooldown = 5; held = 0
        return true
    }
}
