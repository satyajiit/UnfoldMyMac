import Foundation
import UnfoldMyMacCore

struct ThermalWallpaperProvider: WallpaperDataProvider {
    let id = "thermal"
    let interval: TimeInterval = 2
    func sample(at date: Date) async throws -> WallpaperDataSample {
        Self.snapshot(ProcessInfo.processInfo.thermalState, at: date)
    }
    static func snapshot(_ state: ProcessInfo.ThermalState, at date: Date) -> WallpaperDataSample {
        let level: Double
        let label: String
        let advice: String
        switch state {
        case .nominal: (level, label, advice) = (0, "NOMINAL", "Your Mac has thermal headroom.")
        case .fair: (level, label, advice) = (1, "WARM", "The system is warming up.")
        case .serious: (level, label, advice) = (2, "SERIOUS", "Pause heavy work to help your Mac cool down.")
        case .critical: (level, label, advice) = (3, "CRITICAL", "Give your Mac a break and check ventilation.")
        @unknown default: return .init(timestamp: date, text: ["thermal.state": "UNKNOWN", "thermal.advice": "Thermal information unavailable"])
        }
        return .init(timestamp: date, numbers: ["thermal.pressure": level / 3],
                     text: ["thermal.state": label, "thermal.advice": advice])
    }
}
