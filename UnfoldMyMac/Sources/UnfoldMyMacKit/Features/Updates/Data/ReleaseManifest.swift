import Foundation
import UnfoldMyMacCore

/// `release.json`, written by `script/verify_release.sh` and published with every release.
///
/// This is the project's own schema rather than GitHub's, and it carries the one fact the releases
/// API cannot: the macOS version the build needs. Without it a future release could hand someone a
/// build their Mac refuses to launch, with no way back from inside the app.
struct ReleaseManifest: Decodable, Sendable {
    let status: String
    let version: String
    let tag: String
    let assetUrl: URL
    let sha256: String
    let architectures: [String]
    let minimumMacOS: String
    let signing: String

    static let availableStatus = "available"
    static let notarizedSigning = "developer-id-notarized"

    func release() throws -> UpdateRelease {
        guard status == Self.availableStatus, signing == Self.notarizedSigning else {
            throw UpdateError.releaseHasNoDownload
        }
        guard let version = AppVersion(version), !version.isPrerelease,
              AppVersion(tag) == version else { throw UpdateError.releaseVersionMismatch }
        guard sha256.count == 64,
              sha256.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) else {
            throw UpdateError.unreadableChecksum
        }
        let name = assetUrl.lastPathComponent
        guard name == UpdateRelease.expectedAssetName(for: version) else { throw UpdateError.releaseVersionMismatch }
        try UpdateRelease.validate(assetUrl)
        return UpdateRelease(version: version, assetName: name, assetURL: assetUrl,
                             expectedDigest: sha256, minimumSystem: minimumMacOS)
    }
}
