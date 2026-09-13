import Foundation
import UnfoldMyMacCore

/// Every path the updater touches, in one place and injectable.
///
/// Downloads live under Application Support; staging lives beside the application being replaced, so
/// the final exchange is always within a single volume. Tests point `root` at a temporary directory,
/// which is what keeps the whole chain exercisable without writing into a real installation.
struct UpdatePaths: Sendable {
    var root: URL

    static let live = UpdatePaths(root: AppSupportPaths.updates)

    var lock: URL { root.appendingPathComponent(".lock") }
    var handoff: URL { root.appendingPathComponent("handoff.json") }

    func downloadDirectory(for version: AppVersion) -> URL {
        root.appendingPathComponent("v\(version)", isDirectory: true)
    }
    func diskImage(for release: UpdateRelease) -> URL {
        downloadDirectory(for: release.version).appendingPathComponent(release.assetName)
    }
    func resumeData(for version: AppVersion) -> URL {
        downloadDirectory(for: version).appendingPathComponent("resume.data")
    }
    func mountPoint() -> URL {
        root.appendingPathComponent("mnt-\(UUID().uuidString)", isDirectory: true)
    }
    /// Hidden, and a sibling of the target so the swap is a same-volume exchange.
    func staging(beside target: URL) -> URL {
        target.deletingLastPathComponent()
            .appendingPathComponent(".\(AppIdentity.name)-update-\(UUID().uuidString)", isDirectory: true)
    }
    func prepare(_ fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
    }
}
