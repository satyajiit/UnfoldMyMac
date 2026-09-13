import Foundation
import IOKit.hid

/// Best-effort native SPU reader. Only accel/gyro drivers are configured, never keyboard or lid devices.
@MainActor final class GardenMotionSensor: GardenMotionReading {
    private var endpoints: [GardenMotionEndpoint] = []
    private(set) var diagnostic = "Motion sensors are paused."
    func start() {
        guard endpoints.isEmpty else { return }
        endpoints = [3, 9].compactMap { GardenMotionEndpoint(usage: $0) }
        diagnostic = endpoints.isEmpty ? "No accessible motion sensors. Pointer parallax still works." : "Waiting for motion sensor readings…"
    }
    func read(now: Double) -> GardenMotionSample {
        let acceleration = endpoints.first { $0.usage == 3 }?.report.read(now: now)
        let rotation = endpoints.first { $0.usage == 9 }?.report.read(now: now)
        if acceleration != nil && rotation != nil { diagnostic = "Tilt and gyroscope are active." }
        else if acceleration != nil { diagnostic = "Tilt is active; no gyroscope readings." }
        else if rotation != nil { diagnostic = "Gyroscope is active; no tilt readings." }
        else { diagnostic = "No live motion readings. Pointer parallax still works." }
        return .init(acceleration: acceleration, rotation: rotation)
    }
    func stop() { endpoints.removeAll(); diagnostic = "Motion sensors are paused." }
}

/// Report memory, run-loop registration and driver settings share one lifetime.
@MainActor private final class GardenMotionEndpoint {
    let usage: Int
    let report = GardenMotionReport()
    private let device: IOHIDDevice
    private let driver: io_service_t
    private var previous: [String: CFTypeRef] = [:]
    private let buffer: UnsafeMutablePointer<UInt8>
    // AppKit always owns the process's main run loop.
    private let loop = CFRunLoopGetMain()!

    init?(usage: Int) {
        guard let driver = Self.service(className: "AppleSPUHIDDriver", usage: usage) else { return nil }
        guard let service = Self.service(className: "AppleSPUHIDDevice", usage: usage) else { IOObjectRelease(driver); return nil }
        defer { IOObjectRelease(service) }
        guard let device = IOHIDDeviceCreate(nil, service), IOHIDDeviceOpen(device, 0) == kIOReturnSuccess else {
            IOObjectRelease(driver); return nil
        }
        self.usage = usage; self.driver = driver; self.device = device
        buffer = .allocate(capacity: 4096)
        for (key, value) in [("SensorPropertyReportingState", 1), ("SensorPropertyPowerState", 1), ("ReportInterval", 33_333)] {
            previous[key] = IORegistryEntryCreateCFProperty(driver, key as CFString, nil, 0)?.takeRetainedValue() ?? NSNumber(value: 0)
            IORegistryEntrySetCFProperty(driver, key as CFString, NSNumber(value: value))
        }
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 4096, GardenMotionReport.callback, Unmanaged.passUnretained(report).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, loop, CFRunLoopMode.commonModes.rawValue)
    }
    isolated deinit {
        IOHIDDeviceUnscheduleFromRunLoop(device, loop, CFRunLoopMode.commonModes.rawValue)
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 4096, nil, nil)
        IOHIDDeviceClose(device, 0)
        for (key, value) in previous { IORegistryEntrySetCFProperty(driver, key as CFString, value) }
        IOObjectRelease(driver); buffer.deallocate()
    }
    private static func service(className: String, usage: Int) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            let page = IORegistryEntryCreateCFProperty(service, "PrimaryUsagePage" as CFString, nil, 0)?.takeRetainedValue() as? Int
            let kind = IORegistryEntryCreateCFProperty(service, "PrimaryUsage" as CFString, nil, 0)?.takeRetainedValue() as? Int
            if page == 0xFF00 && kind == usage { return service }
            IOObjectRelease(service)
        }
        return nil
    }
}
