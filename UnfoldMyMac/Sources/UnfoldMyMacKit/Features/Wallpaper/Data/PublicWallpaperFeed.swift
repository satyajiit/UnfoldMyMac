import Foundation
import UnfoldMyMacCore

struct PublicWallpaperJSON: Sendable {
    var session: URLSession = HTTPBodyReader.ephemeralSession
    func fetch<Value: Decodable & Sendable>(_ url: URL) async throws -> Value {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppIdentity.name, forHTTPHeaderField: "User-Agent")
        let (body, response) = try await HTTPBodyReader(session: session).body(for: request, limit: 524_288)
        guard response.statusCode == 200 else { throw WallpaperError.unavailable("Public feed unavailable; retrying shortly") }
        return try JSONDecoder().decode(Value.self, from: body)
    }
}

struct PublicWallpaperReading<Value: Sendable>: Sendable {
    let value: Value
    let fetched: Date
    var cached: Bool
}

/// Shared between previews and desktops. Bounded storage, conservative retries and a hard expiry.
actor PublicWallpaperFeed<Value: Decodable & Sendable> {
    private struct Entry {
        var reading: PublicWallpaperReading<Value>?
        var schedule: RefreshSchedule
    }
    private var entries: [URL: Entry] = [:]
    private let client: PublicWallpaperJSON
    private let validate: @Sendable (Value) throws -> Void
    init(client: PublicWallpaperJSON = .init(), validate: @escaping @Sendable (Value) throws -> Void) {
        self.client = client; self.validate = validate
    }
    func read(_ url: URL, at date: Date, refresh: TimeInterval, expiry: TimeInterval) async throws -> PublicWallpaperReading<Value> {
        var entry = entries[url] ?? Entry(schedule: .init(refreshInterval: refresh, retryInterval: 60))
        if entry.schedule.isDue(at: date) {
            // Reserve the retry window before suspension so two surfaces do not double-poll.
            entry.schedule.failed("Refreshing", at: date)
            if entries.count >= 32, entries[url] == nil { entries.removeAll() }
            entries[url] = entry
            do {
                let value: Value = try await client.fetch(url)
                try Task.checkCancellation()
                try validate(value)
                entry.reading = .init(value: value, fetched: date, cached: false)
                entry.schedule.succeeded(at: date)
            } catch {
                if Task.isCancelled || error is CancellationError {
                    entries[url] = nil
                    throw CancellationError()
                }
                entry.schedule.failed("Offline", at: date)
            }
            entries[url] = entry
        }
        guard var reading = entry.reading, (-5...expiry).contains(date.timeIntervalSince(reading.fetched)) else {
            throw WallpaperError.unavailable("Waiting for a fresh public reading · retries every minute")
        }
        reading.cached = entry.schedule.failure != nil
        return reading
    }
}
