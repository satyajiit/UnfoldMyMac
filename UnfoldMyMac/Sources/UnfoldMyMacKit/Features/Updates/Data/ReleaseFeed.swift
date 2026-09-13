import Foundation
import UnfoldMyMacCore

protocol ReleaseFeedReading: Sendable {
    func latest() async throws -> UpdateRelease
    /// Best effort. Release notes are worth showing but never worth failing an update over.
    func notes(for release: UpdateRelease) async -> String
    /// The published `SHA256SUMS`, fetched only when the manifest did not already carry a digest.
    func checksums(at url: URL) async throws -> String
}

/// Finds the newest release, preferring the project's own manifest over the GitHub API.
///
/// The manifest is a plain asset behind a permanent redirect, so reading it spends no API quota —
/// which matters because the unauthenticated allowance is counted per address, and the wallpaper
/// connector is already spending it on the same Mac. The API stays as the fallback for releases cut
/// before the manifest existed, and as the source of release notes.
struct ReleaseFeed: ReleaseFeedReading {
    var session: URLSession = HTTPBodyReader.ephemeralSession
    var cache = HTTPConditionalCache()
    var manifestAddress = AppIdentity.latestReleaseManifest
    var apiAddress = AppIdentity.latestReleaseAPI

    func latest() async throws -> UpdateRelease {
        do { return try await fromManifest() } catch { return try await fromAPI() }
    }

    private func fromManifest() async throws -> UpdateRelease {
        guard let url = URL(string: manifestAddress) else { throw UpdateError.serverUnavailable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppIdentity.name, forHTTPHeaderField: "User-Agent")
        cache.prepare(&request)
        let (data, http) = try await body(for: request, limit: 8192)
        guard http.statusCode == 200 || http.statusCode == 304 else { throw UpdateError.releaseHasNoDownload }
        guard let payload = cache.body(for: http, received: data, url: url) else { throw UpdateError.unreadableChecksum }
        return try JSONDecoder().decode(ReleaseManifest.self, from: payload).release()
    }

    private func fromAPI() async throws -> UpdateRelease {
        guard let url = URL(string: apiAddress) else { throw UpdateError.serverUnavailable }
        let (data, http) = try await body(for: githubRequest(url), limit: 1_048_576)
        if let limited = UpdateNetworkError.rateLimit(http) { throw limited }
        switch http.statusCode {
        case 200, 304: break
        case 404: throw UpdateError.releaseHasNoDownload
        default: throw UpdateError.serverUnavailable
        }
        guard let payload = cache.body(for: http, received: data, url: url) else { throw UpdateError.serverUnavailable }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: payload).release()
    }

    func notes(for release: UpdateRelease) async -> String {
        guard release.notes.isEmpty else { return release.notes }
        guard let url = URL(string: apiAddress) else { return "" }
        guard let (data, http) = try? await body(for: githubRequest(url), limit: 1_048_576),
              http.statusCode == 200 || http.statusCode == 304,
              let payload = cache.body(for: http, received: data, url: url) else { return "" }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(GitHubRelease.self, from: payload),
              AppVersion(decoded.tagName) == release.version else { return "" }
        return decoded.body ?? ""
    }

    func checksums(at url: URL) async throws -> String {
        try UpdateRelease.validate(url)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(AppIdentity.name, forHTTPHeaderField: "User-Agent")
        let (data, http) = try await body(for: request, limit: ChecksumManifest.byteLimit)
        guard http.statusCode == 200 else { throw UpdateError.noChecksumPublished }
        return String(decoding: data, as: UTF8.self)
    }

    private func githubRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(AppIdentity.name, forHTTPHeaderField: "User-Agent")
        cache.prepare(&request)
        return request
    }

    /// Everything the shared reader throws is re-emitted as an update error, so a wallpaper error
    /// can never surface in an update message.
    private func body(for request: URLRequest, limit: Int) async throws -> (Data, HTTPURLResponse) {
        do { return try await HTTPBodyReader(session: session).body(for: request, limit: limit) }
        catch { throw UpdateNetworkError.mapped(error) }
    }
}
