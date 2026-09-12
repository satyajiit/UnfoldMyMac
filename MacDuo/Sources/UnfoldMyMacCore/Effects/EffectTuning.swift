import Foundation

/// Bounds shared by settings sanitising, the model and the settings UI.
extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self { min(range.upperBound, max(range.lowerBound, self)) }
}

public enum EffectTuning {
    public static let activationRange: ClosedRange<Double> = 60...180
    public static let completionRange: ClosedRange<Double> = 0.4...1
    public static let defaultCompletionFraction = 0.8
}
