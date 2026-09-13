import CryptoKit
import Foundation
import UnfoldMyMacCore

/// Hashes a file a megabyte at a time.
///
/// The disk image is tens of megabytes, so reading it into memory to hash it would be a needless
/// spike on a machine the update is already asking to find room on.
enum StreamingSHA256 {
    static let chunkSize = 1 << 20

    static func digest(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        // The same hex spelling ShaderLibraryCache and RecordStore already use.
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
