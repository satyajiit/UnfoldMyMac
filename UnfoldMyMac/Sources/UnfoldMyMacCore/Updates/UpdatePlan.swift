import Foundation

/// Everything about this Mac that can refuse an update, gathered once so the decision itself is pure.
public struct UpdateFacts: Equatable, Sendable {
    public var eligibility: UpdateEligibility
    public var currentVersion: AppVersion
    public var systemMajorVersion: Int
    public var freeSpaceAtInstall: Int64
    public var freeSpaceAtDownload: Int64
    public var installDirectoryWritable: Bool
    public var installedByCurrentUser: Bool

    public init(eligibility: UpdateEligibility, currentVersion: AppVersion, systemMajorVersion: Int,
                freeSpaceAtInstall: Int64, freeSpaceAtDownload: Int64, installDirectoryWritable: Bool,
                installedByCurrentUser: Bool) {
        self.eligibility = eligibility; self.currentVersion = currentVersion
        self.systemMajorVersion = systemMajorVersion; self.freeSpaceAtInstall = freeSpaceAtInstall
        self.freeSpaceAtDownload = freeSpaceAtDownload; self.installDirectoryWritable = installDirectoryWritable
        self.installedByCurrentUser = installedByCurrentUser
    }
}

public enum UpdateDecision: Equatable, Sendable {
    case proceed
    case alreadyCurrent
    case blocked(UpdateBlock)
    case refuse(UpdateError)
}

/// Every refusal in one pure function, decided before the first byte is spent.
///
/// Checking disk space and writability *before* downloading is the whole point: discovering that
/// `/Applications` is read-only after pulling 54 MB is a worse experience than never starting.
///
/// There is no cross-volume check here because the installer stages beside the application it is
/// replacing, so the exchange is always within one volume by construction. `RenameSwapInstaller`
/// asserts that rather than trusting it.
public enum UpdatePlan {
    /// Disk image plus the staged copy plus the outgoing bundle, with headroom for the next release.
    public static let installHeadroom: Int64 = 400_000_000
    public static let downloadHeadroom: Int64 = 250_000_000

    public static func decide(_ release: UpdateRelease, facts: UpdateFacts) -> UpdateDecision {
        if case .blocked(let block) = facts.eligibility { return .blocked(block) }
        guard release.version > facts.currentVersion else { return .alreadyCurrent }

        if let minimum = release.minimumSystem, let needed = Int(minimum), needed > facts.systemMajorVersion {
            return .refuse(.needsNewerSystem(minimum))
        }
        guard facts.installedByCurrentUser else { return .refuse(.installedByAnotherUser) }
        guard facts.installDirectoryWritable else { return .refuse(.installLocationNotWritable) }
        guard facts.freeSpaceAtDownload >= downloadHeadroom else {
            return .refuse(.notEnoughSpaceToDownload(needed: downloadHeadroom))
        }
        guard facts.freeSpaceAtInstall >= installHeadroom else {
            return .refuse(.notEnoughSpaceToInstall(needed: installHeadroom))
        }
        return .proceed
    }
}
