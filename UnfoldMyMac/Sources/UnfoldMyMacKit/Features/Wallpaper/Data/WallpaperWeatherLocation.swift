import Foundation
import UnfoldMyMacCore

struct WallpaperWeatherLocation: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    var country: String?
    var admin1: String?
    var timezone: String?
    var label: String { [name, admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") }
    var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude) && !name.isEmpty && label.count <= 180
    }
    static func search(_ query: String, client: PublicWallpaperJSON = .init()) async throws -> [Self] {
        struct Results: Decodable, Sendable { var results: [WallpaperWeatherLocation]? }
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [.init(name: "name", value: String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))),
                          .init(name: "count", value: "5"), .init(name: "language", value: "en")]
        let result: Results = try await client.fetch(url.url!)
        return (result.results ?? []).filter(\.isValid)
    }
    var forecastURL: URL {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [.init(name: "latitude", value: String(latitude)), .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,is_day"),
            .init(name: "daily", value: "sunrise,sunset"), .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"), .init(name: "forecast_days", value: "2")]
        return url.url!
    }
}
