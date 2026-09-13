import Foundation
import IOKit.ps
import UnfoldMyMacCore

/// Public power-source values only; unknown estimates stay unknown.
struct PowerWallpaperProvider: WallpaperDataProvider {
    let id = "power"
    let interval: TimeInterval = 2

    func sample(at date: Date) async throws -> WallpaperDataSample {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            throw WallpaperError.unavailable("Power information unavailable")
        }
        for source in sources {
            guard let values = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  values[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = values[kIOPSCurrentCapacityKey] as? Double,
                  let maximum = values[kIOPSMaxCapacityKey] as? Double, maximum > 0 else { continue }
            let charging = values[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = values[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let minutes = values[charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int
            return Self.snapshot(level: current / maximum, charging: charging, plugged: plugged,
                                 minutes: minutes, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, at: date)
        }
        return .init(timestamp: date, text: ["power.level": "AC POWER", "power.state": "No internal battery",
                                             "power.detail": "Connected to desktop power"])
    }

    static func snapshot(level: Double, charging: Bool, plugged: Bool, minutes: Int?, lowPower: Bool,
                         at date: Date) -> WallpaperDataSample {
        let level = min(1, max(0, level))
        let state = charging ? "HEALING FACTOR ACTIVE" : plugged ? "RECOVERED · ON AC" : level < 0.2 ? "TIME TO RECHARGE" : "ENERGY IN RESERVE"
        let estimate = minutes.flatMap { $0 > 0 ? "About \($0) min \(charging ? "to full" : "remaining")" : nil }
        let detail = lowPower ? "Low Power Mode is on" : estimate ?? (plugged ? "Mac manages charging automatically" : "macOS battery estimate unavailable")
        return .init(timestamp: date, numbers: ["power.battery": level, "power.charging": charging ? 1 : 0,
                                                "power.low": level < 0.2 ? 1 : 0],
                     text: ["power.level": String(format: "%.0f%%", level * 100), "power.state": state, "power.detail": detail])
    }
}
