import Foundation
import UnfoldMyMacCore

/// API adapter seam: supply a URLRequest (including authorization) from your connector.
/// Templates never own credentials, URLs, network calls or polling tasks.
actor WallpaperHTTPProvider: WallpaperDataProvider {
    nonisolated let id: String
    nonisolated let interval: TimeInterval
    private let request: URLRequest
    private let session: URLSession
    nonisolated var fingerprint: String { request.url?.absoluteString ?? "" }
    init(id: String, request: URLRequest, interval: TimeInterval = 5, session: URLSession = HTTPBodyReader.ephemeralSession) throws {
        guard !id.isEmpty, !id.contains("."), interval.isFinite,
              let url = request.url, url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(url.host ?? "")) else {
            throw WallpaperError.invalidData
        }
        self.id = id; self.request = request; self.interval = max(1, interval); self.session = session
    }
    func sample(at date: Date) async throws -> WallpaperDataSample {
        var request = request; request.timeoutInterval = 5
        let (data, response) = try await HTTPBodyReader(session: session).body(for: request, limit: 65_536)
        guard response.statusCode == 200 else {
            throw WallpaperError.unavailable("The API connection did not return a successful snapshot.")
        }
        let sample = try WallpaperSnapshotJSON.decode(data, namespace: id)
        guard WallpaperDataSample.freshness.contains(date.timeIntervalSince(sample.timestamp)) else { throw WallpaperError.unavailable("The API snapshot is stale.") }
        return sample
    }
}
