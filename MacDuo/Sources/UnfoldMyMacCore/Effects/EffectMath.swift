import Foundation

public enum EffectMath {
    public static let closedLid = 5.0
    public static let defaultActivation = 125.0
    public static func closure(lid: Double, activation: Double) -> Double {
        guard lid.isFinite, activation.isFinite else { return 0 }
        return min(1, max(0, (activation - lid) / max(1, activation - closedLid)))
    }
    /// Finish the visual sequence before physical lid travel ends; hold the final state afterward.
    public static func calibratedClosure(_ raw: Double, completionFraction: Double) -> Double {
        guard raw.isFinite else { return 0 }
        let end = completionFraction.isFinite ? completionFraction.clamped(to: EffectTuning.completionRange) : EffectTuning.defaultCompletionFraction
        return min(1, max(0, raw / end))
    }
    /// The inclusive trigger gets a subtle first frame; there is no invisible travel below it.
    /// Preview remains fully clear at zero, and live completion still lands at the configured angle.
    public static func liveProgress(lid: Double, activation: Double, completionFraction: Double) -> Double {
        guard lid.isFinite, activation.isFinite, lid <= activation else { return 0 }
        let progress = calibratedClosure(closure(lid: lid, activation: activation), completionFraction: completionFraction)
        let onset = 0.004
        return onset + (1 - onset) * progress
    }
    public static func completionAngle(activation: Double, completionFraction: Double) -> Double {
        let end = completionFraction.isFinite ? completionFraction.clamped(to: EffectTuning.completionRange) : EffectTuning.defaultCompletionFraction
        return activation - (activation - closedLid) * end
    }
    public static func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }
    public static func blurRadius(edge: Double, context: EffectContext) -> Double {
        72 * context.motion * pow(min(1, max(0, edge)), 1.35) * context.strength
    }
    public static func darkening(edge: Double, context: EffectContext) -> Double {
        let gradient = min(1, max(0, (edge - 0.2) / 0.8))
        let local = min(1, context.motion * pow(gradient, 1.35) * 2 * context.strength)
        return 1 - (1 - local) * (1 - context.finalFade)
    }
    public static func playClosure(seconds: Double) -> Double {
        let t = seconds.truncatingRemainder(dividingBy: 8.6)
        if t < 1.2 { return 0 }
        if t < 4.3 { return (1 - cos((t - 1.2) / 3.1 * .pi)) / 2 }
        if t < 5.5 { return 1 }
        return (1 + cos((t - 5.5) / 3.1 * .pi)) / 2
    }
}
