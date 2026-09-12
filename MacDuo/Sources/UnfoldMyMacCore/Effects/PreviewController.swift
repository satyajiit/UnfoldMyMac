import Foundation

/// The preview state machine: which effect is being tried, its scrub position or playback clock, and the
/// enabled state to restore when it ends. A value type with no clocks or I/O, so every transition is
/// table-testable.
public struct PreviewController: Equatable, Sendable {
    /// How `end` decides the enabled state it hands back.
    public enum Restore: Sendable {
        /// The state the user had before the preview, or chose during it (L1).
        case previous
        /// Off: the chosen effect itself failed while it was being previewed (P16).
        case disabled
    }
    public enum Transition: Equatable, Sendable { case started, switched, unchanged }

    public private(set) var isPreviewing = false
    public private(set) var isPlaying = false
    public private(set) var effectID: EffectID?
    /// Scrub position in lid travel: 0 open, 1 closed.
    public private(set) var closure = 0.0
    private var playSeconds = 0.0
    private var enabledBefore = false

    public init() {}

    /// Starts previewing `effect`, remembering `enabled` on the first entry; switching effects keeps that memory.
    public mutating func begin(effect: EffectID, enabled: Bool) -> Transition {
        let transition: Transition
        if isPreviewing {
            guard effectID != effect else { return .unchanged }
            transition = .switched
        } else {
            enabledBefore = enabled
            transition = .started
        }
        effectID = effect; isPreviewing = true; isPlaying = false
        closure = 0; playSeconds = 0
        return transition
    }
    /// An on/off choice made while previewing applies once the preview ends instead of being lost (L1).
    public mutating func rememberEnabled(_ value: Bool) { enabledBefore = value }
    /// Resumes the open-close cycle from the current position rather than restarting at "open".
    public mutating func play() {
        guard isPreviewing else { return }
        playSeconds = EffectMath.playSeconds(closure: closure)
        isPlaying = true
    }
    public mutating func pause() { isPlaying = false }
    public mutating func scrub(_ value: Double) {
        isPlaying = false
        closure = value.isFinite ? min(1, max(0, value)) : 0
    }
    /// Moves playback forward by one frame; a paused or scrubbed preview holds its position.
    public mutating func advance(by delta: TimeInterval) {
        guard isPlaying, delta.isFinite, delta > 0 else { return }
        playSeconds += delta
        closure = EffectMath.playClosure(seconds: playSeconds)
    }
    /// Ends the preview and returns the enabled state the runtime should restore.
    @discardableResult public mutating func end(restoring restore: Restore = .previous) -> Bool {
        let restored = restore == .previous ? enabledBefore : false
        self = PreviewController()
        return restored
    }
}
