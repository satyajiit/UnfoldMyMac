import Foundation

/// Failures raised while building Metal state. Every pipeline throws these instead of ad-hoc `NSError` codes.
enum GPUError: LocalizedError, Equatable {
    case metalUnavailable
    case allocationFailed(String)

    var errorDescription: String? {
        switch self {
        case .metalUnavailable: "Metal is unavailable on this Mac."
        case .allocationFailed(let what): "Unable to create \(what)."
        }
    }
}
