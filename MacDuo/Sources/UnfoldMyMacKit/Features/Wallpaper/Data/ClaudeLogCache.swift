import Foundation
import UnfoldMyMacCore

/// Only counters and file cursors reach disk. Incomplete JSON/prompt bytes never enter the cache.
struct ClaudeLogCache {
    let directory: URL
    private var store: RecordStore { RecordStore(directory: directory, format: .propertyList) }
    func load(_ source: URL) throws -> ClaudeCachedLog {
        let key = key(source)
        let size = try store.url(for: key).resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 64*1024*1024 else { throw WallpaperError.invalidData }
        guard let cached = try store.read(ClaudeCachedLog.self, for: key) else { throw CocoaError(.fileNoSuchFile) }
        return cached
    }
    func save(_ value: ClaudeCachedLog, for source: URL) throws { try store.write(value, for: key(source)) }
    private func key(_ source: URL) -> String { source.standardizedFileURL.resolvingSymlinksInPath().path }
}
