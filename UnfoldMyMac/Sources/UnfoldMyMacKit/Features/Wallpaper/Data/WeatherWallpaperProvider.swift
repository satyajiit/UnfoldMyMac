import Foundation
import UnfoldMyMacCore

struct WeatherWallpaperProvider: WallpaperDataProvider {
    let id = "weather"
    let interval: TimeInterval = 5
    let location: WallpaperWeatherLocation
    var feed: PublicWallpaperFeed<WallpaperWeather> = Self.shared
    var fingerprint: String { location.forecastURL.absoluteString + location.label }
    static let shared = PublicWallpaperFeed<WallpaperWeather>(validate: { try $0.validate() })

    func sample(at date: Date) async throws -> WallpaperDataSample {
        do {
            let reading = try await feed.read(location.forecastURL, at: date, refresh: 600, expiry: 7200)
            return Self.snapshot(reading, location: location, at: date)
        } catch {
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            return .init(timestamp: date, text: ["weather.location": location.name.uppercased(),
                "weather.source": "Open-Meteo unavailable · retrying in 1 min", "weather.condition": "Waiting for weather"])
        }
    }
    static func snapshot(_ reading: PublicWallpaperReading<WallpaperWeather>, location: WallpaperWeatherLocation,
                         at date: Date) -> WallpaperDataSample {
        let value = reading.value, current = value.current
        let age = date.timeIntervalSince1970 - current.time
        let fresh = (-300...7200).contains(age)
        let source = "Open-Meteo · " + (fresh ? reading.cached ? "cached · " : "updated " : "stale · ") + value.clock(current.time)
        var text = ["weather.location": location.name.uppercased(), "weather.source": source,
                    "weather.clock": value.clock(date.timeIntervalSince1970)]
        guard fresh else {
            text["weather.condition"] = "Waiting for current conditions"
            return .init(timestamp: date, text: text, status: "Weather reading expired")
        }
        var numbers: [String: Double] = ["weather.available": 1]
        if let temperature = current.temperature_2m {
            text["weather.temperature"] = String(format: "%.0f°C", temperature)
        }
        if let rain = current.precipitation {
            numbers["weather.rain"] = max(0, rain)
            text["weather.rainfall"] = String(format: "%.1f mm precipitation", rain)
        }
        if let wind = current.wind_speed_10m, let direction = current.wind_direction_10m {
            numbers["weather.wind"] = max(0, wind)
            numbers["weather.direction"] = direction.truncatingRemainder(dividingBy: 360)
            numbers["weather.windValid"] = 1
            let degrees = (direction.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let compass = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int((degrees + 22.5) / 45) % 8]
            text["weather.windLabel"] = String(format: "%.0f km/h · %@", wind, compass)
        }
        if let gust = current.wind_gusts_10m { text["weather.gusts"] = String(format: "Gusts %.0f km/h · direction wind comes from", gust) }
        numbers["weather.day"] = current.is_day == 1 ? 1 : 0
        let sun = value.solar(at: date)
        if let progress = sun.progress { numbers["weather.sun"] = progress }
        text["weather.sunNext"] = sun.next; text["weather.sunTimes"] = sun.times
        text["weather.condition"] = value.condition
        return .init(timestamp: date, numbers: numbers, text: text, status: source)
    }
}
