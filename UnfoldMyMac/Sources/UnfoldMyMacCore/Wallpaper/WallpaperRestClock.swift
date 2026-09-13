import Foundation

/// Advances only across observed, awake samples. Sleep and clock jumps never complete a session.
public struct WallpaperRestClock: Sendable {
    public enum Mode: String, Sendable { case focus, eyes }
    public let mode: Mode
    public let workSeconds: Double
    public private(set) var elapsed = 0.0
    public private(set) var resting = false
    public private(set) var completed = 0
    private var previousUptime: Double?

    public init(mode: Mode, minutes: Double) {
        self.mode = mode
        workSeconds = min(60, max(1, minutes.isFinite ? minutes : 25)) * 60
    }
    public mutating func tick(uptime: Double, idle: Double) {
        guard uptime.isFinite, idle.isFinite, idle >= 0 else { return }
        let delta = previousUptime.map { uptime - $0 } ?? 0
        previousUptime = uptime
        if mode == .eyes, idle >= 20 { elapsed = 0; resting = false; return }
        guard delta > 0, delta <= 5 else { return }
        if mode == .focus {
            if !resting && idle >= 60 { return }
            elapsed += delta
            let duration = resting ? 300.0 : workSeconds
            if elapsed >= duration {
                if !resting { completed += 1 }
                resting.toggle(); elapsed = 0
            }
        } else {
            elapsed = min(workSeconds, elapsed + delta)
            resting = elapsed >= workSeconds
        }
    }
    public var progress: Double { min(1, elapsed / (mode == .focus && resting ? 300 : workSeconds)) }
    public var remaining: Double { max(0, (mode == .focus && resting ? 300 : workSeconds) - elapsed) }
}
