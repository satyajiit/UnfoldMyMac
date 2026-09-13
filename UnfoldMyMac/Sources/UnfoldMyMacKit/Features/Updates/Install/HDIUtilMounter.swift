import Foundation
import UnfoldMyMacCore

/// Mounts a release image read-only through `hdiutil`.
///
/// The image is checksum-verified by `hdiutil` (no `-noverify`): about a second, and it turns a
/// corrupt image into a clean tool exit instead of a filesystem-level failure in the kernel.
struct HDIUtilMounter: DiskImageMounting {
    var runner: any ProcessRunning = SystemProcessRunner()
    var paths = UpdatePaths.live
    private var fileManager: FileManager { .default }

    func withMountedImage<T: Sendable>(at image: URL,
                                       _ body: @Sendable (_ mountPoint: URL) async throws -> T) async throws -> T {
        try paths.prepare(fileManager)
        let mountPoint = paths.mountPoint()
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        let attached = try await runner.run(SystemTool.diskImage,
                                            ["attach", image.path, "-readonly", "-nobrowse", "-noautoopen",
                                             "-mountpoint", mountPoint.path], timeout: 120)
        guard attached.succeeded else {
            try? fileManager.removeItem(at: mountPoint)
            throw UpdateError.diskImageCouldNotBeOpened
        }
        // An image can attach with no mountable filesystem; proceeding would read an empty directory.
        guard (try? fileManager.contentsOfDirectory(atPath: mountPoint.path))?.isEmpty == false,
              (try? mountPoint.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true else {
            try? await detach(mountPoint)
            throw UpdateError.diskImageCouldNotBeOpened
        }
        do {
            let value = try await body(mountPoint)
            try await detach(mountPoint)
            return value
        } catch {
            try? await detach(mountPoint)
            throw error
        }
    }

    /// Ask, wait, then insist. `-force` ignores open files, which is safe only because the mount is
    /// read-only and there is nothing to lose.
    private func detach(_ mountPoint: URL) async throws {
        if (try? await runner.run(SystemTool.diskImage, ["detach", mountPoint.path, "-quiet"], timeout: 60))?.succeeded == true {
            try? fileManager.removeItem(at: mountPoint)
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        let forced = try await runner.run(SystemTool.diskImage, ["detach", mountPoint.path, "-force", "-quiet"], timeout: 60)
        guard forced.succeeded else { throw UpdateError.diskImageStillMounted }
        // Only now is it a plain directory again. Removing a live mount point would be a mistake.
        try? fileManager.removeItem(at: mountPoint)
    }
}
