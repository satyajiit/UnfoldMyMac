import Foundation
import Synchronization

/// The validator and body of the last successful response per URL, so the next request is conditional and a
/// 304 answers from here without a body and, on GitHub, without counting against the rate limit (P14).
final class HTTPConditionalCache: Sendable {
    private struct Entry { let validator: String; let body: Data }
    private let entries = Mutex<[URL: Entry]>([:])

    func prepare(_ request: inout URLRequest) {
        guard let url = request.url, let entry = entries.withLock({ $0[url] }) else { return }
        request.setValue(entry.validator, forHTTPHeaderField: "If-None-Match")
    }
    /// The body to decode: the fresh one, remembered when the response carries an ETag, or the cached one on 304.
    func body(for response: HTTPURLResponse, received: Data, url: URL) -> Data? {
        if response.statusCode == 304 { return entries.withLock { $0[url]?.body } }
        if response.statusCode == 200, let validator = response.value(forHTTPHeaderField: "ETag") {
            entries.withLock { $0[url] = Entry(validator: validator, body: received) }
        }
        return received
    }
}
