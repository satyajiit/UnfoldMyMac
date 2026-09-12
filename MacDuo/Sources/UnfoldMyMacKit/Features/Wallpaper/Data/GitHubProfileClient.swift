import Foundation
import UnfoldMyMacCore

struct GitHubProfileClient: Sendable {
    var session: URLSession = HTTPBodyReader.ephemeralSession
    var cache = HTTPConditionalCache()

    static func username(_ input: String) throws -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("https://github.com/"), let url = URL(string: value), url.host == "github.com" {
            value = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if value.hasPrefix("@") { value.removeFirst() }
        guard value.range(of: #"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$"#, options: .regularExpression) != nil else {
            throw WallpaperError.unavailable("Enter a GitHub username or a github.com profile URL.")
        }
        return value
    }
    func profile(_ username: String) async throws -> GitHubProfile {
        try await fetch("users/" + Self.username(username))
    }
    func events(_ username: String) async throws -> [GitHubPublicEvent] {
        try await fetch("users/" + Self.username(username) + "/events/public?per_page=100")
    }
    private func fetch<Value: Decodable & Sendable>(_ path: String) async throws -> Value {
        guard let url = URL(string: "https://api.github.com/" + path) else { throw WallpaperError.invalidData }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("UnfoldMyMac", forHTTPHeaderField: "User-Agent")
        cache.prepare(&request)
        let (data, http) = try await HTTPBodyReader(session: session).body(for: request, limit: 1_048_576)
        switch http.statusCode {
        case 200, 304: break
        case 404: throw WallpaperError.unavailable("That public GitHub profile was not found.")
        case 403, 429: throw WallpaperError.unavailable("GitHub's public API is rate limited. It will retry in a few minutes.")
        default: throw WallpaperError.unavailable("GitHub is unavailable right now. Your connection will retry.")
        }
        guard let body = cache.body(for: http, received: data, url: url) else { throw WallpaperError.invalidData }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: body)
    }
}
