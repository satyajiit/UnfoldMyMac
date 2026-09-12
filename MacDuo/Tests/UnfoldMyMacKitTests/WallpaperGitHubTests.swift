import Foundation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private final class GitHubMockProtocol: URLProtocol, @unchecked Sendable {
    static let requests = Mutex<[String: Int]>([:])
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!, username = url.pathComponents[2]
        Self.requests.withLock { $0[username, default: 0] += 1 }
        let calls = Self.requests.withLock { $0[username] ?? 0 }
        let code = username == "missing" ? 404 : username == "limited" ? 429 : username == "flaky" && calls > 2 ? 503 : 200
        let profile = #"{"login":"satyajiit","public_repos":35,"followers":35,"following":7,"public_gists":2,"created_at":"2016-01-01T00:00:00Z"}"#
        let events = #"[{"id":"1","type":"PushEvent","created_at":"2026-09-01T00:00:00Z"},{"id":"1","type":"PushEvent","created_at":"2026-09-01T00:00:00Z"},{"id":"2","type":"WatchEvent","created_at":"2026-09-01T00:00:00Z"}]"#
        let body = username == "oversized" ? String(repeating: "x", count: 1_048_577) : url.path.hasSuffix("/public") ? events : profile
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func githubProfileInputRejectsPathsAndAcceptsHandles() throws {
    for input in ["satyajiit", " @satyajiit ", "https://github.com/satyajiit/"] {
        #expect(try GitHubProfileClient.username(input) == "satyajiit")
    }
    for input in ["", "../secrets", "https://evil.com/name", "https://github.com/name/repo", "-name", String(repeating: "a", count: 40)] {
        #expect(throws: (any Error).self) { try GitHubProfileClient.username(input) }
    }
}

@Test func githubProviderCachesPublicDataAndCountsPushEventsOnce() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GitHubMockProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let provider = GitHubWallpaperProvider(username: "cache-test", client: .init(session: session))
    let now = Date()
    let first = try await provider.sample(at: now)
    #expect(first.numbers["github.repos"] == 35)
    #expect(first.numbers["github.followers"] == 35)
    #expect(first.numbers["github.pushes"] == 1)
    #expect(first.text["github.handle"] == "@satyajiit")
    #expect(first.text["github.scope"]?.contains("MAY BE DELAYED") == true)
    let heartbeat = try await provider.sample(at: now.addingTimeInterval(299))
    #expect(heartbeat.timestamp == now.addingTimeInterval(299))
    #expect(GitHubMockProtocol.requests.withLock { $0["cache-test"] } == 2)
    _ = try await provider.sample(at: now.addingTimeInterval(300))
    #expect(GitHubMockProtocol.requests.withLock { $0["cache-test"] } == 4)
    for name in ["missing", "limited", "oversized"] {
        await #expect(throws: (any Error).self) { try await GitHubProfileClient(session: session).profile(name) }
    }
    let profile = try await GitHubProfileClient(session: session).profile("partial")
    let partial = GitHubWallpaperProvider.snapshot(profile: profile, events: nil, at: now)
    #expect(partial.numbers["github.repos"] == 35)
    #expect(partial.numbers["github.pushes"] == nil)
    #expect(partial.text["github.scope"]?.contains("UNAVAILABLE") == true)
}

@Test func githubRealProfileIntegrationWhenRequested() async throws {
    guard let username = ProcessInfo.processInfo.environment["UNFOLDMYMAC_GITHUB_TEST_USER"] else { return }
    let client = GitHubProfileClient()
    let profile = try await client.profile(username)
    let events = try await client.events(username)
    let snapshot = GitHubWallpaperProvider.snapshot(profile: profile, events: events, at: .now)
    #expect(profile.login.lowercased() == username.lowercased())
    #expect(snapshot.numbers["github.repos"] == Double(profile.public_repos))
    let pushes = Int(snapshot.numbers["github.pushes"] ?? 0)
    print("GITHUB LIVE: @\(profile.login), \(profile.public_repos) public repos, \(profile.followers) followers, \(pushes) push events in latest feed")
}

// W5: a transient failure keeps the last good profile on screen and retries after a minute.
@Test func githubProviderKeepsTheLastProfileThroughTransientFailures() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GitHubMockProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let provider = GitHubWallpaperProvider(username: "flaky", client: .init(session: session))
    let now = Date()
    let first = try await provider.sample(at: now)
    #expect(first.numbers["github.repos"] == 35)
    let afterFailure = try await provider.sample(at: now.addingTimeInterval(GitHubWallpaperProvider.refreshInterval))
    #expect(afterFailure.numbers["github.repos"] == 35, "Cached values survive a failed refresh")
    #expect(afterFailure.status.contains("retrying in 1 min"))
    #expect(GitHubMockProtocol.requests.withLock { $0["flaky"] } == 4, "Profile and events were requested together")
    _ = try await provider.sample(at: now.addingTimeInterval(GitHubWallpaperProvider.refreshInterval + 30))
    #expect(GitHubMockProtocol.requests.withLock { $0["flaky"] } == 4, "No refetch before the retry interval")
    _ = try await provider.sample(at: now.addingTimeInterval(GitHubWallpaperProvider.refreshInterval + GitHubWallpaperProvider.retryInterval))
    #expect(GitHubMockProtocol.requests.withLock { $0["flaky"] } == 6)
    let never = GitHubWallpaperProvider(username: "missing", client: .init(session: session))
    await #expect(throws: WallpaperError.self) { try await never.sample(at: now) }
}
