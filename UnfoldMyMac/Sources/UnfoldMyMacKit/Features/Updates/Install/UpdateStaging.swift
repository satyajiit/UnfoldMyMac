import Darwin
import Foundation
import UnfoldMyMacCore

/// Turns a downloaded disk image into a verified application sitting beside the one it will replace.
///
/// The order matters more than any single step. The image's signature is checked *before* it is
/// attached, because attaching hands an untrusted file to a kernel filesystem driver; after that,
/// every copy is re-verified, because a signature proved about one file says nothing about the next.
struct UpdateStaging: Sendable {
    var mounter: any DiskImageMounting = HDIUtilMounter()
    var signatures: any CodeSignatureValidating = SecurityCodeSignatureValidator()
    var runner: any ProcessRunning = SystemProcessRunner()
    var paths = UpdatePaths.live

    func stage(_ diskImage: URL, for release: UpdateRelease, over target: URL,
               systemMajorVersion: Int) async throws -> URL {
        try signatures.validate(diskImage, as: .diskImage)

        let staging = try await mounter.withMountedImage(at: diskImage) { mountPoint in
            let application = try mounter.soleApplication(in: mountPoint)
            try signatures.validate(application, as: .application)

            // Read from the signed code object rather than the file: this is the plist the signature
            // just covered, so there is no window in which the two could differ.
            let plist = try signatures.securedInfoPlist(at: application)
            guard let short = plist["CFBundleShortVersionString"] as? String,
                  AppVersion(short) == release.version else { throw UpdateError.releaseVersionMismatch }
            if let minimum = plist["LSMinimumSystemVersion"] as? String,
               let needed = Int(minimum.split(separator: ".").first.map(String.init) ?? minimum),
               needed > systemMajorVersion {
                throw UpdateError.needsNewerSystem(String(needed))
            }

            let staging = paths.staging(beside: target)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try RenameSwapInstaller.assertSameVolume(staging, target)
            let destination = staging.appendingPathComponent("\(AppIdentity.name).app")
            // ditto, never copyItem: the release script's own note explains that anything less
            // produces a bundle that launches and then fails its staple check in front of a user.
            let copied = try await runner.run(SystemTool.copy, [application.path, destination.path], timeout: 600)
            guard copied.succeeded else {
                try? FileManager.default.removeItem(at: staging)
                throw UpdateError.downloadCouldNotBeSaved
            }
            return staging
        }

        let staged = staging.appendingPathComponent("\(AppIdentity.name).app")
        // ditto carries extended attributes across, and a quarantined bundle would be translocated on
        // first launch — leaving the user running a read-only copy from a temporary directory. It is
        // safe to clear here only because the bundle has just been checked more strictly than
        // Gatekeeper would.
        Self.clearQuarantine(at: staged)
        do { try signatures.validate(staged, as: .application) } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        return staging
    }

    /// `com.apple.provenance` is left alone: that one is the system's to manage.
    static func clearQuarantine(at root: URL) {
        var paths = [root.path]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
                                                       options: [])
        while let url = enumerator?.nextObject() as? URL { paths.append(url.path) }
        for path in paths { _ = removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW) }
    }
}
