import Foundation
import UnfoldMyMacCore

struct WallpaperWeather: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let time: Double
        let temperature_2m: Double?
        let precipitation: Double?
        let weather_code: Int?
        let wind_speed_10m: Double?
        let wind_direction_10m: Double?
        let wind_gusts_10m: Double?
        let is_day: Int?
    }
    struct Daily: Decodable, Sendable {
        let sunrise: [Double?]
        let sunset: [Double?]
    }
    let current: Current
    let daily: Daily
    let timezone: String

    func validate() throws {
        let values = [current.time, current.temperature_2m, current.precipitation, current.wind_speed_10m,
                      current.wind_direction_10m, current.wind_gusts_10m].compactMap { $0 }
        guard values.allSatisfy(\.isFinite), current.time > 0, TimeZone(identifier: timezone) != nil,
              current.temperature_2m.map({ (-100...70).contains($0) }) ?? true,
              current.precipitation.map({ (0...1_000).contains($0) }) ?? true,
              current.wind_speed_10m.map({ (0...500).contains($0) }) ?? true,
              current.wind_gusts_10m.map({ (0...500).contains($0) }) ?? true,
              current.wind_direction_10m.map({ (0...360).contains($0) }) ?? true,
              current.is_day == 0 || current.is_day == 1,
              daily.sunrise.count <= 3, daily.sunset.count <= 3,
              (daily.sunrise + daily.sunset).compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw WallpaperError.invalidData
        }
    }
    var condition: String {
        switch current.weather_code ?? -1 {
        case 0: "Clear skies"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51...67: "Rain / drizzle"
        case 71...77: "Snow"
        case 80...82: "Rain showers"
        case 85, 86: "Snow showers"
        case 95...99: "Thunderstorms"
        default: "Conditions unavailable"
        }
    }
    func clock(_ timestamp: Double) -> String {
        Date(timeIntervalSince1970: timestamp).formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: TimeZone(identifier: timezone) ?? .gmt))
    }
    /// Solar progress uses the location's civil day and UTC instants, including DST transitions.
    func solar(at date: Date) -> (progress: Double?, next: String, times: String) {
        let rises = daily.sunrise.compactMap { $0 }.filter { $0 > 0 }
        let sets = daily.sunset.compactMap { $0 }.filter { $0 > 0 }
        let now = date.timeIntervalSince1970
        let next = (rises.map { ($0, "Sunrise") } + sets.map { ($0, "Sunset") }).filter { $0.0 > now }.min { $0.0 < $1.0 }
        let detail = next.map { "\($0.1) in \(Int(ceil(($0.0 - now) / 60))) min" } ?? "No solar event in this forecast"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .gmt
        guard let pair = zip(daily.sunrise, daily.sunset).first(where: { rise, set in
            guard let rise, let set, rise > 0, set > rise else { return false }
            return calendar.isDate(Date(timeIntervalSince1970: rise), inSameDayAs: date)
        }), let rise = pair.0, let set = pair.1 else {
            return (nil, detail, "Sunrise / sunset unavailable at this latitude")
        }
        return (min(1, max(0, (now - rise) / (set - rise))), detail, "↑ \(clock(rise))     ↓ \(clock(set))")
    }
}
