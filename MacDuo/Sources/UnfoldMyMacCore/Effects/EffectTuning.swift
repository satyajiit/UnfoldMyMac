import Foundation

/// Bounds shared by settings sanitising, the model and the settings UI.
extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self { min(range.upperBound, max(range.lowerBound, self)) }
}

public enum EffectTuning {
    public static let activationRange: ClosedRange<Double> = 60...180
    public static let completionRange: ClosedRange<Double> = 0.4...1
    public static let defaultCompletionFraction = 0.8
    /// A missing lid sensor is reopened after this delay, doubling on each failure up to the ceiling.
    public static let sensorReconnectDelay: TimeInterval = 2
    public static let sensorReconnectCeiling: TimeInterval = 60
    /// A reading older than this marks the sensor unavailable.
    public static let sensorStaleAfter: TimeInterval = 1
    /// Capture-frame and GPU-time readouts refresh at this rate; they are diagnostics, not animation.
    public static let telemetryInterval: TimeInterval = 0.25
    /// Frame deltas are clamped so a stalled display link cannot jump the animation clock.
    public static let frameDeltaRange: ClosedRange<TimeInterval> = (1.0 / 240)...0.05
}
