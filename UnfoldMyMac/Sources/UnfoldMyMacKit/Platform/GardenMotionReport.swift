import Foundation
import IOKit.hid
import Synchronization

/// A callback mailbox owns only the most recent vector. C callback isolation never depends on its caller.
final class GardenMotionReport: Sendable {
    private let latest = Mutex((vector: SIMD3<Double>.zero, time: -Double.infinity))
    nonisolated static let callback: IOHIDReportCallback = { context, result, _, _, _, bytes, count in
        guard result == kIOReturnSuccess, let context else { return }
        let report = Unmanaged<GardenMotionReport>.fromOpaque(context).takeUnretainedValue()
        report.receive(UnsafeBufferPointer(start: bytes, count: count), now: ProcessInfo.processInfo.systemUptime)
    }
    func receive(_ bytes: UnsafeBufferPointer<UInt8>, now: Double) {
        // Apple's vendor report: 22 bytes, three signed little-endian Q16 values beginning at byte 6.
        guard bytes.count == 22 else { return }
        var vector = SIMD3<Double>.zero
        for axis in 0..<3 {
            let offset = 6+axis*4
            let raw = UInt32(bytes[offset]) | UInt32(bytes[offset+1])<<8 | UInt32(bytes[offset+2])<<16 | UInt32(bytes[offset+3])<<24
            vector[axis] = Double(Int32(bitPattern: raw))/65536
        }
        latest.withLock { $0 = (vector, now) }
    }
    func read(now: Double) -> SIMD3<Double>? {
        latest.withLock { now >= $0.time && now-$0.time < 0.3 ? $0.vector : nil }
    }
}
