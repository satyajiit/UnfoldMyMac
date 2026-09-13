import Foundation

/// Who asked. A background poll and a menu click differ in exactly one way that matters: whether the
/// user is owed an answer. Carrying it into the transition keeps that out of ad-hoc booleans.
public enum UpdateTrigger: Equatable, Sendable {
    case automatic
    case manual
}

/// Where a failure happened, so the UI can offer the right retry.
public enum UpdatePhase: Equatable, Sendable {
    case check, download, verify, stage
}

public struct UpdateFailure: Equatable, Sendable {
    public let error: UpdateError
    public let phase: UpdatePhase
    public init(_ error: UpdateError, phase: UpdatePhase) { self.error = error; self.phase = phase }
    public var message: String { error.errorDescription ?? "" }
}

/// What the app knows about updating itself.
///
/// There is deliberately no case meaning "a background check failed". A quiet failure returns to
/// `idle` and lives only in the retry schedule, so an unreachable network can never raise UI.
public enum UpdateState: Equatable, Sendable {
    /// This copy must not replace itself. Terminal for the process.
    case unsupported(UpdateBlock)
    case idle
    case checking(UpdateTrigger)
    case upToDate(AppVersion, checkedAt: Date)
    case available(UpdateRelease)
    case downloading(UpdateRelease, received: Int64, total: Int64)
    case verifying(UpdateRelease)
    case readyToRelaunch(UpdateRelease, staged: URL)
    case failed(UpdateFailure)

    public var release: UpdateRelease? {
        switch self {
        case .available(let release), .downloading(let release, _, _), .verifying(let release),
             .readyToRelaunch(let release, _): release
        default: nil
        }
    }

    public var isBusy: Bool {
        switch self {
        case .checking, .downloading, .verifying: true
        default: false
        }
    }

    /// The sidebar pill. Nothing during a download, because the sheet is already on screen saying so.
    public var badge: String? {
        switch self {
        case .available: "Update"
        case .readyToRelaunch: "Ready"
        default: nil
        }
    }
}

/// What a completed check found.
public enum UpdateOutcome: Equatable, Sendable {
    case discovered(UpdateRelease)
    case none(AppVersion)
    case failure(UpdateError)
}

public extension UpdateError {
    /// Where this failure belongs, so the interface offers the retry that makes sense.
    var phase: UpdatePhase {
        switch self {
        case .signatureRejected, .checksumMismatch, .needsNewerSystem, .releaseVersionMismatch,
             .unreadableChecksum, .noChecksumPublished, .releaseHasNoDownload:
            .verify
        case .diskImageCouldNotBeOpened, .diskImageLayoutUnexpected, .diskImageStillMounted,
             .stagingVolumeMismatch, .appMovedDuringInstall, .updateRolledBack, .updateDidNotFinish:
            .stage
        default:
            .download
        }
    }
}
