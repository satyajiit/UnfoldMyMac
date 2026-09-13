import Foundation

/// Optional physical inputs. The neutral value is a complete, open, quietly lit garden.
/// Pulses are elapsed seconds, or -1 when inactive; no events are queued while suspended.
public struct WallpaperLiveInputs: Equatable, Sendable {
    public var lidOpen = 1.0
    public var sound = 0.0
    public var pollen = -1.0
    public var charging = -1.0
    /// Persistent AC connection, independent of the one-shot charging pulse; interpolated for lighting.
    public var externalPower = 0.0
    public var battery = 0.65
    public var daylight = 0.35
    public var reducedMotion = false
    public var parallax = SIMD2<Double>.zero
    public var motionStir = 0.0
    public init() {}

    public static func openness(angle: Double?) -> Double {
        guard let angle, angle.isFinite else { return 1 }
        return unit((angle - 8) / 102)
    }
    public static func unit(_ value: Double, fallback: Double = 0) -> Double {
        value.isFinite ? min(1, max(0, value)) : fallback
    }
    public static func daylight(at date: Date, calendar: Calendar = .current) -> Double {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
        return unit(0.5 + 0.5 * cos((hour - 13) * .pi / 12))
    }
}
