import Foundation
import Synchronization

/// Drawable callbacks arrive off the main thread. Count displayed frames, not submissions.
final class WallpaperFrameMetrics: Sendable {
    private struct State {
        var lastPresentation = 0.0
        var intervals: [Double] = []
        var gpuSeconds = 0.0
        var completions = 0
    }
    private let state = Mutex(State())
    func presented(at timestamp: Double) {
        state.withLock { value in
            if value.lastPresentation > 0, timestamp > value.lastPresentation {
                value.intervals.append(timestamp - value.lastPresentation)
                if value.intervals.count > 240 { value.intervals.removeFirst() }
            }
            value.lastPresentation = max(value.lastPresentation, timestamp)
        }
    }
    func completed(gpuSeconds: Double) {
        state.withLock { $0.gpuSeconds += max(0, gpuSeconds); $0.completions += 1 }
    }
    func reset() { state.withLock { $0 = State() } }
    func sample(width: Int, height: Int) -> WallpaperRenderStats {
        state.withLock { value in
            let sorted = value.intervals.sorted()
            let duration = value.intervals.reduce(0, +)
            let result = WallpaperRenderStats(fps: duration > 0 ? Double(sorted.count) / duration : 0,
                gpuMilliseconds: value.gpuSeconds / Double(max(1, value.completions)) * 1000,
                width: width, height: height,
                p95FrameMilliseconds: sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))] * 1000)
            value.intervals.removeAll(keepingCapacity: true); value.gpuSeconds = 0; value.completions = 0
            return result
        }
    }
}
