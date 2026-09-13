import Foundation

/// Why this copy of the app must not replace itself.
///
/// A blocked verdict is terminal for the process and stops the updater before any network request is
/// made: a build that cannot install an update has no business asking GitHub whether one exists.
public enum UpdateBlock: String, Equatable, Sendable, CaseIterable {
    /// The bundle's own version string will not parse. Installing over a bundle we cannot identify is
    /// exactly when getting it wrong is most expensive.
    case unreadableVersion
    /// Running out of the build tree. Catches a correctly signed `dist` build that would otherwise
    /// pass the signature check and overwrite the developer's own working copy.
    case developmentTree
    case runningFromDiskImage
    case translocated
    case developmentBuild
    case readOnlyLocation

    public var message: String {
        switch self {
        case .unreadableVersion:
            "UnfoldMyMac cannot read its own version, so it will not try to update itself. Reinstalling from the website will fix it."
        case .developmentTree:
            "Automatic updates are off for builds run from the build folder. Open a released copy to turn them on."
        case .runningFromDiskImage:
            "You are running UnfoldMyMac from its disk image. Drag it to your Applications folder and reopen it, and updates will turn on."
        case .translocated:
            "macOS is running this copy from a temporary read‑only location. Move UnfoldMyMac to your Applications folder and reopen it to turn updates on."
        case .developmentBuild:
            "Automatic updates are off because this copy is not signed with UnfoldMyMac’s Developer ID. Download a release to turn them on."
        case .readOnlyLocation:
            "UnfoldMyMac cannot update itself where it is installed, because that folder is not writable by you. Move it to your Applications folder."
        }
    }
}

public enum UpdateEligibility: Equatable, Sendable {
    case eligible
    case blocked(UpdateBlock)

    public var block: UpdateBlock? {
        if case .blocked(let block) = self { return block }
        return nil
    }
}
