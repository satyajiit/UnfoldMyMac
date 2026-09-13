import AVFoundation
import Accelerate
import Synchronization

/// The real-time callback retains two scalars only. Buffers never leave the callback or reach disk.
final class WallpaperAudioMeter: Sendable {
    private let sample = Mutex((rms: 0.0, timestamp: -Double.infinity))
    /// AVAudioNodeTapBlock has no isolation annotation. Create its callback outside MainActor
    /// and retain Sendable in our signature so AVFAudio can call it on its service queue.
    nonisolated func makeTap() -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { [self] buffer, _ in receive(buffer) }
    }
    func receive(_ buffer: AVAudioPCMBuffer, now: Double = ProcessInfo.processInfo.systemUptime) {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        var peakRMS: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var rms: Float = 0
            vDSP_rmsqv(channels[channel], 1, &rms, vDSP_Length(buffer.frameLength))
            if rms.isFinite { peakRMS = max(peakRMS, rms) }
        }
        let rms = Double(peakRMS)
        sample.withLock {
            // Preserve a brief peak between 30 Hz reads, but expire it after a stalled consumer.
            if now - $0.timestamp > 0.25 || rms > $0.rms { $0 = (rms, now) }
        }
    }
    func read(now: Double) -> Double {
        sample.withLock {
            let rms = now - $0.timestamp < 0.25 ? $0.rms : 0
            $0 = (0, -.infinity)
            return rms
        }
    }
    func reset() { sample.withLock { $0 = (0, -.infinity) } }
}
