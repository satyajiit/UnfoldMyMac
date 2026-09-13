import Foundation
import UnfoldMyMacCore

struct SteamPlayerResponse: Decodable, Sendable {
    struct Response: Decodable, Sendable { let player_count: Int?; let result: Int }
    let response: Response
    func validate() throws {
        guard response.result == 1, let count = response.player_count, (0...100_000_000).contains(count) else {
            throw WallpaperError.invalidData
        }
    }
}
struct SteamNewsResponse: Decodable, Sendable {
    struct News: Decodable, Sendable { let appid: Int; let newsitems: [Item] }
    struct Item: Decodable, Sendable { let title: String; let date: Double; let feedname: String }
    let appnews: News
    func validate() throws {
        guard appnews.appid == 2358720, appnews.newsitems.count <= 10,
              appnews.newsitems.allSatisfy({ $0.date.isFinite && $0.date > 0 }) else { throw WallpaperError.invalidData }
    }
}

/// Public aggregate counts and publisher announcements; no Steam account or in-game access.
struct SteamWallpaperProvider: WallpaperDataProvider {
    let id = "wukong"
    let interval: TimeInterval = 5
    var players = Self.playerFeed
    var news = Self.newsFeed
    static let playerFeed = PublicWallpaperFeed<SteamPlayerResponse>(validate: { try $0.validate() })
    static let newsFeed = PublicWallpaperFeed<SteamNewsResponse>(validate: { try $0.validate() })
    static let playerURL = URL(string: "https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid=2358720")!
    static let newsURL = URL(string: "https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=2358720&count=3&maxlength=1&feeds=steam_community_announcements")!
    func sample(at date: Date) async throws -> WallpaperDataSample {
        async let count = optionalPlayers(at: date)
        async let updates = optionalNews(at: date)
        let (current, latest) = await (count, updates)
        try Task.checkCancellation()
        var text = ["wukong.scope": "STEAM PLAYERS WORLDWIDE", "wukong.news": "Publisher updates unavailable",
                    "wukong.source": "Steam unavailable · retrying in 1 min"]
        var numbers: [String: Double] = [:]
        if let current, let count = current.value.response.player_count {
            numbers["wukong.players"] = Double(count)
            numbers["wukong.crowd"] = min(1, log10(Double(count) + 1) / 6)
            text["wukong.source"] = "Steam · \(current.cached ? "cached" : "updated") " + current.fetched.formatted(date: .omitted, time: .shortened)
        }
        if let latest, let item = latest.value.appnews.newsitems.filter({ $0.feedname == "steam_community_announcements" }).max(by: { $0.date < $1.date }) {
            text["wukong.news"] = String(item.title.prefix(150))
            text["wukong.newsDate"] = "Publisher update · " + Date(timeIntervalSince1970: item.date).formatted(date: .abbreviated, time: .omitted)
                + (latest.cached ? " · cached" : "")
        }
        return .init(timestamp: date, numbers: numbers, text: text)
    }
    private func optionalPlayers(at date: Date) async -> PublicWallpaperReading<SteamPlayerResponse>? {
        try? await players.read(Self.playerURL, at: date, refresh: 120, expiry: 600)
    }
    private func optionalNews(at date: Date) async -> PublicWallpaperReading<SteamNewsResponse>? {
        try? await news.read(Self.newsURL, at: date, refresh: 900, expiry: 86_400)
    }
}
