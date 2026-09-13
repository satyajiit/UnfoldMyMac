import Foundation

/// Everything that can stop an update, with the sentence the user reads.
///
/// Copy rules, asserted by `UpdateErrorCopyTests`: every case is a complete sentence that ends in a
/// full stop, names the next thing to try, and contains no file path — the updater must never show a
/// user their own home directory.
public enum UpdateError: Error, LocalizedError, Equatable, Sendable, CaseIterable {
    // Network
    case offline
    case connectionLost
    case captivePortal
    case nameResolutionFailed
    case secureConnectionFailed
    case clockSkew
    case timedOut
    case unexpectedRedirect
    case rateLimited(until: Date?)
    case serverUnavailable

    // What the release published
    case noChecksumPublished
    case unreadableChecksum
    case releaseHasNoDownload
    case releaseVersionMismatch
    case diskImageLayoutUnexpected

    // The bytes that arrived
    case downloadIncomplete
    case checksumMismatch
    case downloadTooLarge
    case downloadCouldNotBeSaved

    // Space
    case notEnoughSpaceToDownload(needed: Int64)
    case notEnoughSpaceToInstall(needed: Int64)
    case ranOutOfSpace

    // Installing
    case diskImageCouldNotBeOpened
    case diskImageStillMounted
    case signatureRejected
    case needsNewerSystem(String)
    case installLocationNotWritable
    case installedByAnotherUser
    case appMovedDuringInstall
    case stagingVolumeMismatch
    case anotherCopyIsUpdating
    case updateDidNotFinish(installedVersion: String)
    case updateRolledBack

    public var errorDescription: String? {
        switch self {
        case .offline:
            "There is no internet connection right now. UnfoldMyMac will look for the update again once you are back online."
        case .connectionLost:
            "The download stopped when the connection dropped. Your progress was saved, so choose Resume to pick up where it left off."
        case .captivePortal:
            "A Wi‑Fi sign‑in page answered instead of the download. Sign in to the network in Safari, then try again."
        case .nameResolutionFailed:
            "The download server could not be found. This is usually a network problem, so try again in a few minutes."
        case .secureConnectionFailed:
            "The secure connection to GitHub could not be established. UnfoldMyMac will not download an update over a connection it cannot verify."
        case .clockSkew:
            "Your Mac’s date and time look wrong, so the secure connection could not be verified. Set the date and time automatically in System Settings, then try again."
        case .timedOut:
            "The download timed out. Your progress was saved, so choose Resume to continue."
        case .unexpectedRedirect:
            "The download was redirected somewhere unexpected, so it was stopped."
        case .rateLimited(let until):
            if let until {
                "GitHub is limiting requests from your network. UnfoldMyMac will check again after \(until.formatted(date: .omitted, time: .shortened))."
            } else {
                "GitHub is limiting requests from your network. UnfoldMyMac will check again a little later."
            }
        case .serverUnavailable:
            "GitHub is having trouble right now. UnfoldMyMac will try again shortly."
        case .noChecksumPublished:
            "This release did not publish a checksum, so UnfoldMyMac cannot confirm the download is intact. Download it from the website instead."
        case .unreadableChecksum:
            "The checksum for this release could not be read, so nothing was downloaded. You can download the release from the website instead."
        case .releaseHasNoDownload:
            "The newest release does not include a Mac download yet. UnfoldMyMac will check again later."
        case .releaseVersionMismatch:
            "This release’s files do not match its version number, so UnfoldMyMac will not install it."
        case .diskImageLayoutUnexpected:
            "This release’s disk image is not laid out the way UnfoldMyMac expects, so it will not be installed. Download it from the website instead."
        case .downloadIncomplete:
            "The download finished early and is incomplete. UnfoldMyMac will download it again."
        case .checksumMismatch:
            "The download does not match the checksum published for this release, so it was deleted. This is usually a damaged download; try again, and download from the website if it keeps happening."
        case .downloadTooLarge:
            "The download is far larger than this release should be, so it was stopped."
        case .downloadCouldNotBeSaved:
            "The download could not be saved. Check that your startup disk has free space, then try again."
        case .notEnoughSpaceToDownload(let needed):
            "There is not enough free space to download the update. About \(Self.size(needed)) is needed."
        case .notEnoughSpaceToInstall(let needed):
            "There is not enough free space to install the update. About \(Self.size(needed)) is needed, so free some space and try again."
        case .ranOutOfSpace:
            "The download ran out of space partway through. Free some space and try again."
        case .diskImageCouldNotBeOpened:
            "The downloaded disk image could not be opened. It was deleted, so try downloading the update again."
        case .diskImageStillMounted:
            "The update’s disk image is still mounted. Eject UnfoldMyMac in the Finder, then try again."
        case .signatureRejected:
            "The downloaded copy of UnfoldMyMac is not signed by its developer, so it was deleted and nothing was installed. Download the app from the website if you want to reinstall it."
        case .needsNewerSystem(let system):
            "This update needs macOS \(system) or later. Update macOS first, and UnfoldMyMac will offer the new version again."
        case .installLocationNotWritable:
            "UnfoldMyMac cannot update itself where it is installed, because it does not have permission to write there. You can still install the new version yourself."
        case .installedByAnotherUser:
            "UnfoldMyMac was installed by another user account, so this account cannot replace it. Ask that user to update it, or install your own copy in your Applications folder."
        case .appMovedDuringInstall:
            "UnfoldMyMac moved while the update was being installed, so nothing was changed."
        case .stagingVolumeMismatch:
            "UnfoldMyMac is installed on a different disk from the one holding the download, so it cannot install the update safely. You can still install the new version yourself."
        case .anotherCopyIsUpdating:
            "Another copy of UnfoldMyMac is already downloading this update."
        case .updateDidNotFinish(let installed):
            "The last update did not finish. UnfoldMyMac is still on version \(installed), so choose Check for Updates to try again."
        case .updateRolledBack:
            "The update could not be completed, so your existing version was put back. Nothing was lost, and you can try again."
        }
    }

    /// Whether retrying is pointless and the way forward is to install a release by hand.
    ///
    /// Refusing an update is only half an answer; every one of these leaves the user somewhere they
    /// can still get the new version from.
    public var suggestsManualDownload: Bool {
        switch self {
        case .installLocationNotWritable, .installedByAnotherUser, .stagingVolumeMismatch,
             .signatureRejected, .noChecksumPublished, .unreadableChecksum, .diskImageLayoutUnexpected,
             .releaseVersionMismatch:
            true
        default:
            false
        }
    }

    private static func size(_ bytes: Int64) -> String { bytes.formatted(.byteCount(style: .file)) }

    /// One representative value per case, so the copy tests can walk every message.
    public static var allCases: [UpdateError] {
        [.offline, .connectionLost, .captivePortal, .nameResolutionFailed, .secureConnectionFailed, .clockSkew,
         .timedOut, .unexpectedRedirect, .rateLimited(until: nil), .rateLimited(until: Date(timeIntervalSince1970: 0)),
         .serverUnavailable, .noChecksumPublished, .unreadableChecksum, .releaseHasNoDownload, .releaseVersionMismatch,
         .diskImageLayoutUnexpected, .downloadIncomplete, .checksumMismatch, .downloadTooLarge, .downloadCouldNotBeSaved,
         .notEnoughSpaceToDownload(needed: 250_000_000), .notEnoughSpaceToInstall(needed: 400_000_000), .ranOutOfSpace,
         .diskImageCouldNotBeOpened, .diskImageStillMounted, .signatureRejected, .needsNewerSystem("27"),
         .installLocationNotWritable, .installedByAnotherUser, .appMovedDuringInstall, .stagingVolumeMismatch,
         .anotherCopyIsUpdating, .updateDidNotFinish(installedVersion: "1.0.1"), .updateRolledBack]
    }
}
