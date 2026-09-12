import Foundation
import UnfoldMyMacCore

actor GitHubWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "github"
    nonisolated let interval: TimeInterval = 5
    private let username: String
    nonisolated var fingerprint: String { username }
    private let client: GitHubProfileClient
    private var cached: WallpaperDataSample?
    private var schedule = RefreshSchedule(refreshInterval: GitHubWallpaperProvider.refreshInterval, retryInterval: GitHubWallpaperProvider.retryInterval)
    init(username: String, client: GitHubProfileClient = .init()) { self.username = username; self.client = client }

    /// A transient failure keeps the last good profile on screen and retries sooner than the normal
    /// refresh; cancellation is never recorded as a failure.
    func sample(at date: Date) async throws -> WallpaperDataSample {
        if schedule.isDue(at: date) {
            do {
                async let profile = client.profile(username)
                async let events = client.events(username)
                let fetchedProfile = try await profile
                let fetchedEvents: [GitHubPublicEvent]?
                do { fetchedEvents = try await events }
                catch is CancellationError { throw CancellationError() }
                catch { fetchedEvents = nil }
                cached = Self.snapshot(profile: fetchedProfile, events: fetchedEvents, at: date)
                schedule.succeeded(at: date)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                schedule.failed(error.localizedDescription, at: date)
            }
        }
        guard var sample = cached else {
            throw WallpaperError.unavailable(schedule.failure ?? "Connect a public GitHub profile to bring this city to life.")
        }
        // Heartbeat keeps cached public values visible between deliberately slow API polls.
        sample.timestamp = date
        if let failure = schedule.failure { sample.status = "Showing the last fetched profile · \(failure) · retrying in 1 min" }
        return sample
    }
    static let refreshInterval: TimeInterval = 300
    static let retryInterval: TimeInterval = 60
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
