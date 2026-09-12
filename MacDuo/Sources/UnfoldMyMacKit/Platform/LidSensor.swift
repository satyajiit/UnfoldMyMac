import Foundation
import IOKit.hid

@MainActor protocol LidReading: AnyObject {
    var diagnostic: String { get }
    func read() -> Double?
}

/// Read-only lid-angle HID. Undocumented Apple report; may be absent on M1/M2.
@MainActor
final class LidSensor: LidReading {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    private var device: IOHIDDevice?
    private(set) var diagnostic = "No readable lid sensor"

    init() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            kIOHIDPrimaryUsagePageKey as String: 0x0020,
            kIOHIDPrimaryUsageKey as String: 0x008A,
        ] as CFDictionary)
        guard IOHIDManagerOpen(manager, 0) == kIOReturnSuccess else {
            diagnostic = "HID access failed"
            return
        }
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        for candidate in devices {
            guard IOHIDDeviceOpen(candidate, 0) == kIOReturnSuccess else { continue }
            device = candidate
            if let angle = read() {
                diagnostic = "Lid sensor \(Int(angle))°"
                return
            }
            IOHIDDeviceClose(candidate, 0)
            device = nil
        }
        diagnostic = "Found \(devices.count) matching HID device(s), no readable angle"
    }

    func read() -> Double? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        let angle = Double(UInt16(report[1]) | UInt16(report[2]) << 8)
        return (0...180).contains(angle) ? angle : nil
    }

    isolated deinit {
        if let device { IOHIDDeviceClose(device, 0) }
        IOHIDManagerClose(manager, 0)
    }
}
