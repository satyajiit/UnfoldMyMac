import Darwin
import Foundation

/// An advisory lock shared by every copy of the app on this Mac.
///
/// Two running instances would otherwise download and stage the same release over each other. The
/// pattern is the one `RecordStore` already uses for concurrent hook invocations.
final class UpdateLock {
    private let descriptor: Int32

    init?(at url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        descriptor = open(url.path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
    }
    private var released = false

    func release() {
        guard !released else { return }
        released = true
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
    deinit { release() }
}
