import Foundation
import UnfoldMyMacCore

enum SignedArtifact: Sendable {
    case application
    case diskImage
}

/// Proves a downloaded artifact was signed by this project before anything is installed or mounted.
///
/// This is the authenticity gate. The checksum beside the download only proves the bytes arrived
/// intact — it comes from the same place the download did, so whoever could replace one could
/// replace both. Only the signature says who made it.
protocol CodeSignatureValidating: Sendable {
    func validate(_ url: URL, as artifact: SignedArtifact) throws
    /// Whether the running copy is itself a release build. A development build fails this, which is
    /// exactly how the updater switches itself off in the build tree.
    func runningApplicationIsRelease() -> Bool
    /// The secured `Info.plist` — the one covered by the signature just validated, so there is no
    /// window in which the file on disk could differ from the file that was checked.
    func securedInfoPlist(at url: URL) throws -> [String: Any]
}
