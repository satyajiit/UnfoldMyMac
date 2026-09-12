import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private final class WallpaperMockURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let code = url.path == "/failure" ? 503 : 200
        let date = Date().addingTimeInterval(url.path == "/stale" ? -60 : 0).ISO8601Format(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        let body = url.path == "/oversized" ? String(repeating: "x", count: 65_537) : "{\"timestamp\":\"\(date)\",\"numbers\":{\"build.jobs\":8},\"text\":{},\"status\":\"Live\"}"
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func wallpaperHTTPAdapterAcceptsFreshSnapshotsAndRejectsErrors() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WallpaperMockURLProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    func provider(_ path: String) throws -> WallpaperHTTPProvider {
        try WallpaperHTTPProvider(id: "build", request: URLRequest(url: URL(string: "https://wallpaper.test/" + path)!), session: session)
    }
    #expect(try await provider("fresh").sample(at: .now).numbers["build.jobs"] == 8)
    for path in ["failure", "stale", "oversized"] {
        await #expect(throws: (any Error).self) { try await provider(path).sample(at: .now) }
    }
    #expect(throws: WallpaperError.invalidData) {
        try WallpaperHTTPProvider(id: "build", request: URLRequest(url: URL(string: "http://example.com")!))
    }
}
