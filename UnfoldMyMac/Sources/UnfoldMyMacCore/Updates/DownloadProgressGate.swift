import Foundation

/// Decides which download callbacks are worth telling the interface about.
///
/// A 54 MB transfer reports progress far faster than a window can usefully redraw, and every
/// published change invalidates the observing views. Coalescing here keeps the steady state quiet
/// without the rule living inside a network callback where it cannot be tested.
public struct DownloadProgressGate: Equatable, Sendable {
    public var fractionStep: Double
    public var interval: TimeInterval
    private var lastFraction: Double = -1
    private var lastPublish: TimeInterval = -.greatestFiniteMagnitude

    public init(fractionStep: Double = 0.005, interval: TimeInterval = 0.25) {
        self.fractionStep = fractionStep; self.interval = interval
    }

    /// True when this sample should reach the interface. The final byte always does, so a finished
    /// download never sits at 99%.
    public mutating func shouldPublish(received: Int64, total: Int64, at time: TimeInterval) -> Bool {
        guard total > 0 else { return publish(0, time) }
        if received >= total { return publish(1, time) }
        let fraction = Double(received) / Double(total)
        guard fraction - lastFraction >= fractionStep || time - lastPublish >= interval else { return false }
        return publish(fraction, time)
    }

    private mutating func publish(_ fraction: Double, _ time: TimeInterval) -> Bool {
        lastFraction = fraction; lastPublish = time
        return true
    }
}
