import Foundation

/// What the effects runtime is doing, as a value the UI formats. Effect cases carry the effect that is actually
/// rendered, which differs from the chosen one under Reduce Transparency (L9).
public enum EffectRuntimeStatus: Equatable, Sendable {
    case off
    case ready
    case sleeping
    case blocked(DisplaySafetyGate.State)
    case preparing(EffectID)
    case previewing(EffectID)
    /// Enabled and rendering, waiting for the lid to reach the activation angle.
    case armed(activation: Double)
    case active(EffectID)
    case screenRecordingNeeded
    case unavailable

    /// The status while an effect is installed: not ready yet, previewing, waiting for the lid, or active.
    public static func rendering(ready: Bool, previewing: Bool, lidAngle: Double?, activation: Double, rendered: EffectID, requested: EffectID) -> EffectRuntimeStatus {
        if !ready { return .preparing(rendered) }
        if previewing { return .previewing(requested) }
        return (lidAngle ?? 180) > activation ? .armed(activation: activation) : .active(rendered)
    }
}
