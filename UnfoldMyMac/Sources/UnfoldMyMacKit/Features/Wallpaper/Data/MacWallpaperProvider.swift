import Foundation
import IOKit.ps
import UnfoldMyMacCore

actor MacWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "mac"
    nonisolated let interval: TimeInterval = 1
    private var previousCPU: [UInt32]?

    func sample(at date: Date) async throws -> WallpaperDataSample {
        var numbers: [String: Double] = [:]
        if let cpu = cpuUsage() { numbers["mac.cpu"] = cpu }
        if let memory = memoryUsage() {
            numbers["mac.memory"] = memory * 100
            numbers["mac.memoryGB"] = memory * Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        }
        var text = ["mac.status": (numbers["mac.cpu"] ?? 0) > 65 ? "IN THE ZONE." : "ROOM TO THINK."]
        if let battery = batteryLevel() {
            numbers["mac.battery"] = battery.0
            numbers["mac.pluggedIn"] = battery.1 ? 1 : 0
            text["mac.power"] = battery.1 ? "PLUGGED IN" : "ON BATTERY"
        } else { text["mac.power"] = "DESKTOP POWER" }
        return .init(timestamp: date, numbers: numbers, text: text)
    }
    private func cpuUsage() -> Double? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
        defer { previousCPU = ticks }
        guard let previousCPU else { return nil }
        let delta = zip(ticks, previousCPU).map { Double($0 &- $1) }
        let total = delta.reduce(0, +)
        return total > 0 ? min(100, max(0, (1 - delta[Int(CPU_STATE_IDLE)] / total) * 100)) : 0
    }
    private func memoryUsage() -> Double? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // Physical footprint estimate: active + wired + compressor, excluding purgeable pages.
        let pages = Double(info.active_count) + Double(info.wire_count) + Double(info.compressor_page_count) - Double(info.purgeable_count)
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        return min(1, max(0, pages * Double(pageSize) / Double(ProcessInfo.processInfo.physicalMemory)))
    }
    private func batteryLevel() -> (Double, Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? Double,
                  let maximum = description[kIOPSMaxCapacityKey] as? Double, maximum > 0 else { continue }
            return (min(100, max(0, current / maximum * 100)), description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return nil
    }
}
