import Foundation
import Synchronization

/// Completion and presentation callbacks arrive off the main thread; everything here is lock-protected.
final class FrameMetrics: Sendable {
    private struct State {
        var lastPresentation = 0.0
        var intervals: [Double] = []
        var gpuSeconds = 0.0
        var completions = 0
        var inFlight = 0
        var lastGPUSeconds = 0.0
        var failures = 0
    }
    private let state = Mutex(State())

    var inFlight: Int { state.withLock { $0.inFlight } }
    var lastGPUSeconds: Double { state.withLock { $0.lastGPUSeconds } }
    /// Command buffers that did not complete successfully; the renderer resubmits the last frame after one.
    var failures: Int { state.withLock { $0.failures } }

    func began() { state.withLock { $0.inFlight += 1 } }
    func completed(gpuSeconds: Double, succeeded: Bool) {
        state.withLock { value in
            value.inFlight = max(0, value.inFlight - 1)
            value.lastGPUSeconds = max(0, gpuSeconds)
            if succeeded { value.gpuSeconds += max(0, gpuSeconds); value.completions += 1 } else { value.failures += 1 }
        }
    }
    func presented(at timestamp: Double) {
        state.withLock { value in
            if value.lastPresentation > 0, timestamp > value.lastPresentation {
                value.intervals.append(timestamp - value.lastPresentation)
                if value.intervals.count > 240 { value.intervals.removeFirst() }
            }
            value.lastPresentation = max(value.lastPresentation, timestamp)
        }
    }
    /// Clears the sampling window; frames in flight keep being accounted for.
    func reset() {
        state.withLock { value in
            value.lastPresentation = 0; value.intervals.removeAll(keepingCapacity: true); value.gpuSeconds = 0; value.completions = 0
        }
    }
    func sample(width: Int, height: Int) -> RenderStats {
        state.withLock { value in
            let sorted = value.intervals.sorted()
            let duration = value.intervals.reduce(0, +)
            let result = RenderStats(fps: duration > 0 ? Double(sorted.count) / duration : 0,
                gpuMilliseconds: value.gpuSeconds / Double(max(1, value.completions)) * 1000,
                width: width, height: height,
                p95FrameMilliseconds: sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))] * 1000)
            value.intervals.removeAll(keepingCapacity: true); value.gpuSeconds = 0; value.completions = 0
            return result
        }
    }
}
