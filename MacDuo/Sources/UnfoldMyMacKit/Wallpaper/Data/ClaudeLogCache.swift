import CryptoKit
import Foundation
import UnfoldMyMacCore

struct ClaudeCachedLog: Codable {
    let inode: UInt64
    let offset: UInt64
    let modified: Date
    let ledger: ClaudeUsageLedger
}

/// Only counters and file cursors reach disk. Incomplete JSON/prompt bytes never enter the cache.
struct ClaudeLogCache {
    let directory: URL
    func load(_ source: URL) throws -> ClaudeCachedLog {
        let url = location(source)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 64*1024*1024 else { throw WallpaperError.invalidData }
        return try PropertyListDecoder().decode(ClaudeCachedLog.self, from: Data(contentsOf: url))
    }
    func save(_ value: ClaudeCachedLog, for source: URL) throws {
        let data = try PropertyListEncoder().encode(value)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: location(source), options: .atomic)
    }
    private func location(_ source: URL) -> URL {
        let path = source.standardizedFileURL.resolvingSymlinksInPath().path
        let hash = SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash + ".plist")
    }
}
