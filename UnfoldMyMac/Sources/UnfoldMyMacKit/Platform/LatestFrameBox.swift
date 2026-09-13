import Synchronization

/// Hands the newest captured frame from the capture queue to the main actor, one hop at a time: frames that
/// arrive while a hop is pending replace the one waiting instead of queueing behind it (P3).
final class LatestFrameBox: Sendable {
    private struct State { var frame: DesktopFrame?; var hopPending = false }
    private let state = Mutex(State())

    /// Stores `frame`; returns `true` when the caller should schedule a hop because none is pending.
    func offer(_ frame: DesktopFrame) -> Bool {
        state.withLock { state in
            state.frame = frame
            guard !state.hopPending else { return false }
            state.hopPending = true
            return true
        }
    }
    /// The frame for the hop that is now running, clearing the pending flag for the next one.
    func take() -> DesktopFrame? {
        state.withLock { state in
            defer { state.frame = nil; state.hopPending = false }
            return state.frame
        }
    }
    func clear() { state.withLock { $0 = State() } }
}
