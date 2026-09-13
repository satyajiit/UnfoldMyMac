import Foundation
import UnfoldMyMacCore

/// Turns whatever the networking stack threw into a sentence worth showing.
///
/// Also the boundary that keeps `WallpaperError` — which the shared body reader throws — from ever
/// reaching an update surface talking about wallpapers.
enum UpdateNetworkError {
    static func mapped(_ error: any Error) -> UpdateError {
        if error is CancellationError { return .connectionLost }
        guard let url = error as? URLError else { return .serverUnavailable }
        switch url.code {
        case .notConnectedToInternet:
            return .offline
        case .networkConnectionLost:
            return .connectionLost
        case .cannotFindHost, .dnsLookupFailed:
            return .nameResolutionFailed
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .clientCertificateRejected, .clientCertificateRequired:
            return .secureConnectionFailed
        case .serverCertificateHasBadDate, .serverCertificateNotYetValid:
            return .clockSkew
        case .timedOut:
            return .timedOut
        case .httpTooManyRedirects, .redirectToNonExistentLocation:
            return .unexpectedRedirect
        case .cancelled:
            return .connectionLost
        case .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            return .serverUnavailable
        }
    }

    /// GitHub answers a spent allowance with 403 and a reset time. Honouring it is the difference
    /// between backing off and being locked out for the rest of the hour.
    static func rateLimit(_ response: HTTPURLResponse) -> UpdateError? {
        guard response.statusCode == 403 || response.statusCode == 429 else { return nil }
        let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
        guard response.statusCode == 429 || remaining == "0" else { return nil }
        let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init)
        return .rateLimited(until: reset.map { Date(timeIntervalSince1970: $0) })
    }
}
