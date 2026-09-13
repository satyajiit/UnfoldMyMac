import Foundation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private let manifestBody = """
{"status":"available","version":"1.0.2","tag":"v1.0.2",\
"assetUrl":"https://github.com/satyajiit/UnfoldMyMac/releases/download/v1.0.2/UnfoldMyMac-1.0.2.dmg",\
"sha256":"\(String(repeating: "a", count: 64))","architectures":["arm64"],"minimumMacOS":"26",\
"signing":"developer-id-notarized","verifiedAt":"2026-09-13"}
"""
private let apiBody = """
{"tag_name":"v1.0.2","body":"## Added\\n- A thing","draft":false,"prerelease":false,\
"published_at":"2026-09-13T12:33:51Z","assets":[\
{"name":"UnfoldMyMac-1.0.2.dmg","browser_download_url":"https://github.com/satyajiit/UnfoldMyMac/releases/download/v1.0.2/UnfoldMyMac-1.0.2.dmg","size":54,"content_type":"application/x-apple-diskimage"},\
{"name":"SHA256SUMS","browser_download_url":"https://github.com/satyajiit/UnfoldMyMac/releases/download/v1.0.2/SHA256SUMS","size":88,"content_type":"application/octet-stream"}]}
"""

/// Behaviour is keyed off the URL rather than shared mutable state, so tests running in parallel
/// cannot disturb one another — the same approach `GitHubMockProtocol` takes.
private final class ReleaseMockProtocol: URLProtocol, @unchecked Sendable {
    static let requests = Mutex<[String: Int]>([:])
    static let headers = Mutex<[String: [String: String]]>([:])

    static func count(_ path: String) -> Int { requests.withLock { $0[path] ?? 0 } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let path = url.path
        Self.requests.withLock { $0[path, default: 0] += 1 }
        let isManifest = url.lastPathComponent == "release.json"
        let isAPI = url.host == "api.github.com"
        if isAPI { Self.headers.withLock { $0[path] = request.allHTTPHeaderFields ?? [:] } }
        let status = path.contains("gone") ? 404 : path.contains("limited") ? 403 : 200
        let body = isManifest ? manifestBody : isAPI ? apiBody
            : "\(String(repeating: "a", count: 64))  UnfoldMyMac-1.0.2.dmg\n"
        var fields: [String: String] = [:]
        if status == 403 { fields["X-RateLimit-Remaining"] = "0"; fields["X-RateLimit-Reset"] = "1800003600" }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                                              headerFields: fields)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private struct FeedHarness {
    let feed: ReleaseFeed
    let session: URLSession
    let manifestPath: String
    let apiPath: String

    /// `tag` keeps each test on its own paths; `manifest`/`api` choose the status those paths answer.
    init(_ tag: String, manifest: String = "ok", api: String = "ok") {
        manifestPath = "/satyajiit/UnfoldMyMac/releases/\(tag)-\(manifest)/download/release.json"
        apiPath = "/repos/satyajiit/UnfoldMyMac/releases/\(tag)-\(api)"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReleaseMockProtocol.self]
        session = URLSession(configuration: configuration)
        feed = ReleaseFeed(session: session,
                           manifestAddress: "https://github.com" + manifestPath,
                           apiAddress: "https://api.github.com" + apiPath)
    }
    func finish() { session.invalidateAndCancel() }
}

@Test func theManifestAnswersWithoutTouchingTheRateLimitedAPI() async throws {
    let harness = FeedHarness("manifest-only")
    defer { harness.finish() }
    let release = try await harness.feed.latest()
    #expect(release.version == AppVersion("1.0.2"))
    #expect(release.minimumSystem == "26", "Only the manifest can say which macOS a build needs")
    #expect(release.expectedDigest?.count == 64, "The manifest carries the digest, so no second fetch is needed")
    #expect(ReleaseMockProtocol.count(harness.apiPath) == 0,
            "The wallpaper connector already spends the API allowance; a routine check must not")
}

@Test func theAPIAnswersWhenAReleasePredatesTheManifest() async throws {
    let harness = FeedHarness("fallback", manifest: "gone")
    defer { harness.finish() }
    let release = try await harness.feed.latest()
    #expect(release.version == AppVersion("1.0.2"))
    #expect(release.checksumURL != nil, "Without a manifest digest the checksum file has to be fetched")
    let headers = ReleaseMockProtocol.headers.withLock { $0[harness.apiPath] ?? [:] }
    #expect(headers["Accept"] == "application/vnd.github+json")
    #expect(headers["X-GitHub-Api-Version"] == "2026-03-10")
    #expect(headers["User-Agent"] == AppIdentity.name)
}

@Test func aSpentRateLimitIsReportedWithTheTimeItLifts() async throws {
    let harness = FeedHarness("limits", manifest: "gone", api: "limited")
    defer { harness.finish() }
    await #expect(throws: UpdateError.rateLimited(until: Date(timeIntervalSince1970: 1_800_003_600))) {
        try await harness.feed.latest()
    }
}

@Test func theChecksumFetchRefusesAnOriginWeDoNotPublishFrom() async throws {
    let harness = FeedHarness("origin")
    defer { harness.finish() }
    await #expect(throws: UpdateError.unexpectedRedirect) {
        try await harness.feed.checksums(at: URL(string: "https://example.com/SHA256SUMS")!)
    }
}

@Test func networkFailuresBecomeSentencesRatherThanErrorCodes() {
    #expect(UpdateNetworkError.mapped(URLError(.notConnectedToInternet)) == .offline)
    #expect(UpdateNetworkError.mapped(URLError(.networkConnectionLost)) == .connectionLost)
    #expect(UpdateNetworkError.mapped(URLError(.cannotFindHost)) == .nameResolutionFailed)
    #expect(UpdateNetworkError.mapped(URLError(.secureConnectionFailed)) == .secureConnectionFailed)
    #expect(UpdateNetworkError.mapped(URLError(.serverCertificateHasBadDate)) == .clockSkew)
    #expect(UpdateNetworkError.mapped(URLError(.timedOut)) == .timedOut)
    #expect(UpdateNetworkError.mapped(URLError(.httpTooManyRedirects)) == .unexpectedRedirect)
    // The shared body reader throws a wallpaper error; it must never surface in an update message.
    #expect(UpdateNetworkError.mapped(WallpaperError.invalidData) == .serverUnavailable)
}
