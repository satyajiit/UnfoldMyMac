import Foundation

/// When a slow or remote source is polled again: the normal cadence after a success, a shorter retry after a
/// failure, with the last failure kept for status copy so the previous good value stays on screen (W5).
public struct RefreshSchedule: Equatable, Sendable {
    public let refreshInterval: TimeInterval
    public let retryInterval: TimeInterval
    public private(set) var nextFetch = Date.distantPast
    public private(set) var failure: String?

    public init(refreshInterval: TimeInterval, retryInterval: TimeInterval) {
        self.refreshInterval = refreshInterval; self.retryInterval = retryInterval
    }
    public func isDue(at date: Date) -> Bool { date >= nextFetch }
    public mutating func succeeded(at date: Date) { failure = nil; nextFetch = date.addingTimeInterval(refreshInterval) }
    public mutating func failed(_ message: String, at date: Date) { failure = message; nextFetch = date.addingTimeInterval(retryInterval) }
}
