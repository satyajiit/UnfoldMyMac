import Foundation
import UnfoldMyMacCore

/// Reads a bounded response body. Bytes stream into a preallocated buffer so a broken or hostile
/// endpoint cannot grow memory past the limit, and the app's own ephemeral session never shares
/// cookies or caches with the rest of the process.
struct HTTPBodyReader: Sendable {
    static let ephemeralSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    var session: URLSession = HTTPBodyReader.ephemeralSession

    func body(for request: URLRequest, limit: Int) async throws -> (data: Data, response: HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw WallpaperError.invalidData }
        guard http.expectedContentLength <= Int64(limit) else { throw WallpaperError.invalidData }
        var buffer: [UInt8] = []
        buffer.reserveCapacity(http.expectedContentLength > 0 ? Int(http.expectedContentLength) : min(limit, 16_384))
        for try await byte in bytes {
            guard buffer.count < limit else { throw WallpaperError.invalidData }
            buffer.append(byte)
            if buffer.count & 0xFFFF == 0 { try Task.checkCancellation() }
        }
        return (Data(buffer), http)
    }
}
