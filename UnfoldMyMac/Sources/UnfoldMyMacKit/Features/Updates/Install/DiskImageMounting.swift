import Foundation
import UnfoldMyMacCore

/// Attaches a disk image for the duration of one operation.
///
/// Scoped rather than open/close, because that is the only shape that guarantees the image is
/// detached on every path — including a thrown error and a cancelled task. An `isolated deinit`
/// cannot do it: deinit cannot await, and a task spawned from one is not guaranteed to run during
/// process teardown, which is exactly when a mount would be left behind.
protocol DiskImageMounting: Sendable {
    func withMountedImage<T: Sendable>(at image: URL,
                                       _ body: @Sendable (_ mountPoint: URL) async throws -> T) async throws -> T
}

extension DiskImageMounting {
    /// The single application a release image must contain. A symbolic link is refused: it would let
    /// the image point the installer at a bundle it never verified.
    func soleApplication(in mountPoint: URL, fileManager: FileManager = .default) throws -> URL {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let entries = (try? fileManager.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: keys,
                                                            options: [])) ?? []
        let applications = entries.filter { url in
            guard url.pathExtension == "app" else { return false }
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.isDirectory == true && values?.isSymbolicLink != true
        }
        guard applications.count == 1, let application = applications.first else {
            throw UpdateError.diskImageLayoutUnexpected
        }
        return application
    }
}
