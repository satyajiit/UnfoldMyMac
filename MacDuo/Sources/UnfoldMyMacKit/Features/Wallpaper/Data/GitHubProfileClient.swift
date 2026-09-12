import Foundation
import UnfoldMyMacCore

struct GitHubProfileClient: Sendable {
    var session: URLSession = .shared

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
        var request = URLRequest(url: URL(string: "https://api.github.com/" + path)!)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("UnfoldMyMac", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw WallpaperError.invalidData }
        switch http.statusCode {
        case 200: break
        case 404: throw WallpaperError.unavailable("That public GitHub profile was not found.")
        case 403, 429: throw WallpaperError.unavailable("GitHub's public API is rate limited. It will retry in a few minutes.")
        default: throw WallpaperError.unavailable("GitHub is unavailable right now. Your connection will retry.")
        }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 1_048_576 else { throw WallpaperError.invalidData }
            data.append(byte)
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: data)
    }
}
