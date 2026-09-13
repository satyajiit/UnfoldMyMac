import Foundation
import UnfoldMyMacCore

struct AuroraWallpaperProvider: WallpaperDataProvider {
    let id = "aurora"
    let interval: TimeInterval = 5
    var store: NOAAWeatherStore = .shared
    func sample(at date: Date) async throws -> WallpaperDataSample {
        Self.snapshot(try await store.read(at: date), at: date)
    }
    static func snapshot(_ state: NOAAWeatherState, at date: Date) -> WallpaperDataSample {
        let forecast = state.forecast
        let stale = forecast.map { date.timeIntervalSince($0.observation) > 7200 || $0.observation.timeIntervalSince(date) > 300 } ?? true
        let kp = state.kp
        let kpStale = kp.map { date.timeIntervalSince($0.date) > 21600 || $0.date.timeIntervalSince(date) > 300 } ?? true
        let value = kp?.value ?? 0
        let phase = Int(max(0, date.timeIntervalSince1970).truncatingRemainder(dividingBy: 36) / 12)
        let remarks: [String]
        if value < 3 { remarks = ["Earth is keeping\nit low-key.", "Quiet sky.\nExcellent planet.", "Solar wind.\nZero drama."] }
        else if value < 5 { remarks = ["The atmosphere\nhas plans tonight.", "A little solar\nmain-character energy.", "The sky is\nwarming up."] }
        else { remarks = ["Earth is having\na dramatic evening.", "The Sun sent\na spicy message.", "The atmosphere\nunderstood the assignment."] }
        var numbers: [String: Double] = [:]
        if let kp { numbers["aurora.kp"] = kp.value; numbers["aurora.energy"] = kp.value / 9 }
        let status = forecast == nil ? "Waiting for NOAA" : (stale ? "Stale forecast" : state.forecastFailed ? "Cached forecast" : "NOAA forecast")
        let time = forecast.map { $0.forecast.formatted(.dateTime.month(.abbreviated).day().hour().minute().timeZone()) } ?? "Awaiting forecast"
        return .init(timestamp: date, numbers: numbers,
            text: ["aurora.headline": kp == nil || kpStale ? "Earth, in\nbeautiful motion." : remarks[phase],
                   "aurora.kpLabel": kp == nil ? "Geomagnetic activity unavailable" : "Planetary Kp" + (kpStale ? " · stale" : state.kpFailed ? " · cached" : ""),
                   "aurora.reading": kp.map { String(format: "%.1f", $0.value) } ?? "—",
                   "aurora.forecast": status + " · " + time,
                   "aurora.condition": kp == nil || kpStale ? "Awaiting current readings" : value < 3 ? "Quiet" : value < 5 ? "Unsettled" : "Geomagnetic storm"],
            status: status + " · refreshes every 5 min · artistic interpretation of NOAA OVATION",
            grids: forecast.map { ["aurora.oval": $0.grid] })
    }
}
