import Foundation

/// The one place a completed check turns into state.
///
/// Every result goes through `next(after:)`, and the trigger is an argument rather than a flag read
/// from somewhere else. That is what makes "a background failure is silent" a property of the type
/// instead of a rule someone has to remember at each call site.
public enum UpdatePolicy {
    /// Six hours between successful checks, a quarter hour after a failure.
    public static let checkInterval: TimeInterval = 6 * 3600
    public static let retryInterval: TimeInterval = 15 * 60
    /// Spread across a fleet behind one address so they do not poll in lockstep.
    public static let jitter: TimeInterval = 30 * 60
    /// However often anything asks, never check more than once an hour.
    public static let floorInterval: TimeInterval = 3600

    public static func schedule() -> RefreshSchedule {
        RefreshSchedule(refreshInterval: checkInterval, retryInterval: retryInterval)
    }

    /// A jittered delay for the next automatic check, in `±jitter` around the cadence.
    public static func jittered(_ interval: TimeInterval, random: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }) -> TimeInterval {
        max(floorInterval, interval + random(-jitter...jitter))
    }

    public static func next(after outcome: UpdateOutcome, trigger: UpdateTrigger,
                            skipped: AppVersion?, current: AppVersion, now: Date) -> UpdateState {
        switch outcome {
        case .failure(let error):
            // A check nobody asked for leaves no trace. The message lives in the retry schedule.
            trigger == .manual ? .failed(UpdateFailure(error, phase: .check)) : .idle
        case .none:
            trigger == .manual ? .upToDate(current, checkedAt: now) : .idle
        case .discovered(let release):
            offer(release, trigger: trigger, skipped: skipped, current: current, now: now)
        }
    }

    private static func offer(_ release: UpdateRelease, trigger: UpdateTrigger,
                              skipped: AppVersion?, current: AppVersion, now: Date) -> UpdateState {
        // Equal counts as up to date. There is no reinstall path and no way to force one.
        guard release.version > current else {
            return trigger == .manual ? .upToDate(current, checkedAt: now) : .idle
        }
        // A skip hides exactly one version, and only from checks the user did not ask for.
        if trigger == .automatic, let skipped, skipped == release.version { return .idle }
        return .available(release)
    }
}
