import Foundation

/// How often the runtime polls the lid when no display link is driving frames (L3). Live rendering reads the
/// sensor before each frame instead, so the poll only has to keep the display gate and the angle readout current.
public enum LidPollingPolicy {
    /// Effects are on or a preview runs: the gate has to notice a closing lid within a frame or two.
    public static let liveInterval: TimeInterval = 1.0 / 30
    /// Nothing renders but the angle is on screen, in the menu bar or in the window.
    public static let idleInterval: TimeInterval = 1.0 / 4

    /// `nil` means no timer at all: effects are off and nobody is looking at the angle.
    public static func interval(enabled: Bool, previewing: Bool, angleObserved: Bool) -> TimeInterval? {
        if enabled || previewing { return liveInterval }
        if angleObserved { return idleInterval }
        return nil
    }
}
