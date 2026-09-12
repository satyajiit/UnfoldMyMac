import Foundation
import UnfoldMyMacCore

actor GitHubWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "github"
    nonisolated let interval: TimeInterval = 5
    private let username: String
    private let client: GitHubProfileClient
    private var cached: WallpaperDataSample?
    private var nextFetch = Date.distantPast
    private var failure: String?
    init(username: String, client: GitHubProfileClient = .init()) { self.username = username; self.client = client }

    func sample(at date: Date) async throws -> WallpaperDataSample {
        if date >= nextFetch {
            nextFetch = date.addingTimeInterval(300)
            do {
                async let profile = client.profile(username)
                async let events = try? client.events(username)
                cached = try await Self.snapshot(profile: profile, events: events, at: date)
                failure = nil
            } catch { failure = error.localizedDescription }
        }
        if let failure { throw WallpaperError.unavailable(failure) }
        guard var sample = cached else { throw WallpaperError.unavailable("Connect a public GitHub profile to bring this city to life.") }
        // Heartbeat keeps cached public values visible between deliberately slow API polls.
        sample.timestamp = date
        return sample
    }
    static func snapshot(profile: GitHubProfile, events: [GitHubPublicEvent]?, at date: Date) -> WallpaperDataSample {
        let recent = Dictionary((events ?? []).prefix(100).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }).values
        let pushes = recent.filter { $0.type == "PushEvent" }.count
        var numbers = ["github.repos": Double(profile.public_repos), "github.followers": Double(profile.followers),
                       "github.gists": Double(profile.public_gists), "github.energy": min(1, 0.2 + Double(pushes) / 30),
                       "github.crowd": min(1, log2(Double(max(0, profile.followers)) + 1)/12)]
        if events != nil { numbers["github.pushes"] = Double(pushes) }
        return .init(timestamp: date,
            numbers: numbers,
            text: ["github.handle": "@" + profile.login, "github.scope": events == nil ? "PUBLIC PROFILE · ACTIVITY FEED UNAVAILABLE" : "PUBLIC PROFILE · LATEST 100 EVENTS · MAY BE DELAYED",
                   "github.status": pushes > 0 ? "THE PUSH-UPS ARE PAYING OFF." : "PLOT TWIST: THE NEXT COMMIT IS YOURS."],
            status: "Public profile · fetched " + date.formatted(date: .omitted, time: .shortened)
                + (events == nil ? " · activity unavailable, retries in 5 min" : " · refreshes every 5 min"))
    }
}
