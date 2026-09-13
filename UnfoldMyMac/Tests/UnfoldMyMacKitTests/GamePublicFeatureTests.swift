import Foundation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

func gameWeatherFixture(at date: Date) -> WallpaperWeather {
    let day = floor(date.timeIntervalSince1970 / 86_400) * 86_400
    return .init(current: .init(time: date.timeIntervalSince1970, temperature_2m: 23, precipitation: 1.2,
                               weather_code: 61, wind_speed_10m: 18, wind_direction_10m: 270, wind_gusts_10m: 32, is_day: 1),
                 daily: .init(sunrise: [day + 21_600, day + 108_000], sunset: [day + 64_800, day + 151_200]), timezone: "UTC")
}

@Test func weatherUsesSelectedTimezoneHandlesMidnightAndExpiresOldReadings() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let value = gameWeatherFixture(at: date)
    try value.validate()
    let city = WallpaperWeatherLocation(id: 1, name: "Test city", latitude: 0, longitude: 0)
    let reading = PublicWallpaperReading(value: value, fetched: date, cached: true)
    let sample = WeatherWallpaperProvider.snapshot(reading, location: city, at: date)
    #expect(sample.text["weather.windLabel"] == "18 km/h · W")
    #expect(sample.text["weather.temperature"] == "23°C")
    #expect(sample.text["weather.source"]?.contains("cached") == true)
    #expect(sample.numbers["weather.rain"] == 1.2)
    #expect(try sample.validated(namespace: "weather") == sample)
    let expired = WeatherWallpaperProvider.snapshot(reading, location: city, at: date.addingTimeInterval(7_201))
    #expect(expired.numbers.isEmpty && expired.text["weather.temperature"] == nil)
    let day = floor(date.timeIntervalSince1970 / 86_400) * 86_400
    let noonTomorrow = Date(timeIntervalSince1970: day + 129_600)
    #expect(value.solar(at: noonTomorrow).progress == 0.5)
    let polar = WallpaperWeather(current: value.current, daily: .init(sunrise: [nil], sunset: [nil]), timezone: "UTC")
    #expect(polar.solar(at: date).progress == nil)
    let japan = WallpaperWeather(current: value.current, daily: value.daily, timezone: "Asia/Tokyo")
    #expect(japan.clock(date.timeIntervalSince1970) != value.clock(date.timeIntervalSince1970))
    #expect(!WallpaperWeatherLocation(id: 2, name: "Bad", latitude: 95, longitude: 0).isValid)
}

private struct FeedTestValue: Decodable, Sendable { let value: Int }
private final class GameFeedProtocol: URLProtocol, @unchecked Sendable {
    static let counts = Mutex<[URL: Int]>([:])
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let count = Self.counts.withLock { values in values[url, default: 0] += 1; return values[url]! }
        let status = count == 2 ? 429 : 200
        let body = count == 3 ? "{\"value\":-1}" : "{\"value\":42}"
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func publicGameFeedsCacheRetryRejectMalformedAndExpireWithoutInventingReadings() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GameFeedProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let feed = PublicWallpaperFeed<FeedTestValue>(client: .init(session: session)) {
        guard $0.value >= 0 else { throw WallpaperError.invalidData }
    }
    let url = URL(string: "https://fixture.test/" + UUID().uuidString)!
    let date = Date.now
    let first = try await feed.read(url, at: date, refresh: 120, expiry: 200)
    #expect(first.value.value == 42 && !first.cached)
    _ = try await feed.read(url, at: date.addingTimeInterval(119), refresh: 120, expiry: 200)
    #expect(GameFeedProtocol.counts.withLock { $0[url] } == 1)
    let rateLimited = try await feed.read(url, at: date.addingTimeInterval(120), refresh: 120, expiry: 200)
    #expect(rateLimited.cached && rateLimited.fetched == date)
    let invalid = try await feed.read(url, at: date.addingTimeInterval(180), refresh: 120, expiry: 200)
    #expect(invalid.value.value == 42 && invalid.cached)
    await #expect(throws: (any Error).self) {
        try await feed.read(url, at: date.addingTimeInterval(201), refresh: 120, expiry: 200)
    }
    let recovered = try await feed.read(url, at: date.addingTimeInterval(240), refresh: 120, expiry: 200)
    #expect(!recovered.cached && recovered.fetched == date.addingTimeInterval(240))
}

@Test func gamePublicEndpointsAndDeviceProvidersIntegrateWhenRequested() async throws {
    guard ProcessInfo.processInfo.environment["UNFOLDMYMAC_GAME_LIVE_CHECK"] == "1" else { return }
    let cities = try await WallpaperWeatherLocation.search("Pune")
    let city = try #require(cities.first)
    let weather = try await WeatherWallpaperProvider(location: city).sample(at: .now)
    #expect(weather.numbers["weather.available"] == 1)
    let steam = try await SteamWallpaperProvider().sample(at: .now)
    #expect(steam.numbers["wukong.players"] != nil)
    #expect(steam.text["wukong.news"] != "Publisher updates unavailable")
    for provider: any WallpaperDataProvider in [PowerWallpaperProvider(), StorageWallpaperProvider(), ThermalWallpaperProvider(), NetworkWallpaperProvider(), RestWallpaperProvider(mode: .focus, minutes: 25)] {
        let sample = try await provider.sample(at: .now)
        _ = try sample.validated(namespace: provider.id)
        #expect(!sample.text.isEmpty)
    }
}
