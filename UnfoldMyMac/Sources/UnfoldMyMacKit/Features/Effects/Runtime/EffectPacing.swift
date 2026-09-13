import AppKit
import QuartzCore

/// The two clocks of the effects runtime: a poll timer whose rate follows `LidPollingPolicy`, and the display
/// link that drives frames while an effect renders. Only the runtime's poll tick creates the link, never a
/// frame callback (L5).
@MainActor final class EffectPacing: NSObject {
    var onTick: (() -> Void)?
    var onFrame: ((TimeInterval) -> Void)?
    private(set) var pollingInterval: TimeInterval?
    private var timer: Timer?
    private var link: CADisplayLink?

    var isLinked: Bool { link != nil }

    /// Replaces the poll timer when the interval changes; `nil` stops polling altogether.
    func setPolling(interval: TimeInterval?) {
        guard interval != pollingInterval else { return }
        timer?.invalidate(); timer = nil
        pollingInterval = interval
        guard let interval else { return }
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onTick?() }
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
    func startLink(on screen: NSScreen) {
        guard link == nil else { return }
        let next = screen.displayLink(target: self, selector: #selector(render(_:)))
        next.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        next.add(to: .main, forMode: .common)
        link = next
    }
    func stopLink() { link?.invalidate(); link = nil }
    func stop() { setPolling(interval: nil); stopLink() }
    @objc private func render(_ link: CADisplayLink) { onFrame?(link.targetTimestamp - link.timestamp) }

    isolated deinit { stop() }
}
