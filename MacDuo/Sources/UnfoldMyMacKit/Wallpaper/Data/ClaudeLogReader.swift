import Foundation
import UnfoldMyMacCore

/// A bounded tail per file. Rotation/truncation replaces that file's contribution.
struct ClaudeLogReader {
    private struct Cursor {
        var inode: UInt64
        var offset: UInt64 = 0
        var modified: Date = .distantPast
        var lines = WallpaperJSONLines()
        var ledger = ClaudeUsageLedger()
    }
    private var files: [URL: Cursor] = [:]
    private var ordered: [URL] = []
    private var recent: [URL] = []
    private var nextFile = 0
    private var discovered: Date = .distantPast
    private let cache: ClaudeLogCache?
    private let readBudget: Int
    private(set) var ledger = ClaudeUsageLedger()
    private(set) var indexing = false
    private(set) var progress = 0.0
    private(set) var cacheError: String?
    init(cacheDirectory: URL? = nil, readBudget: Int = 32*1024*1024) {
        cache = cacheDirectory.map { ClaudeLogCache(directory: $0) }; self.readBudget = readBudget
    }

    mutating func refresh(root: URL, at date: Date) throws {
        var changed = false
        if date.timeIntervalSince(discovered) >= 10 {
            let urls = try discover(root)
            let remaining = Set(urls)
            changed = files.keys.contains { !remaining.contains($0) }
            files = files.filter { remaining.contains($0.key) }
            ordered = urls; discovered = date
            recent = Array(urls.prefix(32)).filter {
                let modified = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return date.timeIntervalSince(modified) < 300
            }
        }
        var budget = readBudget
        for url in recent where files[url] != nil {
            let read = try consume(url, limit: min(budget, 2*1024*1024))
            budget -= read.bytes; changed = changed || read.changed
            if budget <= 0 { break }
        }
        var examined = 0
        while examined < ordered.count && budget > 0 {
            let url = ordered[nextFile % ordered.count]
            nextFile = (nextFile + 1) % ordered.count; examined += 1
            let read = try consume(url, limit: budget)
            budget -= read.bytes
            changed = changed || read.changed
        }
        let total = ordered.reduce(UInt64(0)) { sum, url in sum + UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        let consumed = files.values.reduce(UInt64(0)) { $0 + $1.offset }
        progress = total == 0 ? 1 : min(1, Double(consumed)/Double(total))
        indexing = consumed < total
        if changed {
            var combined = ClaudeUsageLedger()
            for cursor in files.values {
                for record in cursor.ledger.records.values { combined.ingest(record) }
            }
            guard combined.records.count <= 1_000_000 else {
                throw WallpaperError.unavailable("This log folder is too large. Choose a smaller Claude project folder.")
            }
            ledger = combined
        }
    }
    private func discover(_ root: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WallpaperError.unavailable("Claude logs were not found. Choose your Claude projects folder in Data sources.")
        }
        var failure: Error?
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles], errorHandler: { _, error in failure = error; return false }) else {
            throw CocoaError(.fileReadNoPermission)
        }
        var urls: [URL] = []
        for case let url as URL in enumerator {
            let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if properties.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if properties.isRegularFile == true && url.pathExtension == "jsonl" { urls.append(url) }
            guard urls.count <= 50_000 else { throw WallpaperError.unavailable("More than 50,000 logs found. Choose a smaller Claude project folder.") }
        }
        if let failure { throw failure }
        let dated = urls.map { ($0, (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        return dated.sorted { $0.1 > $1.1 }.map(\.0)
    }
    private mutating func consume(_ url: URL, limit: Int) throws -> (bytes: Int, changed: Bool) {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let modified = attrs[.modificationDate] as? Date ?? .distantPast
        let isNew = files[url] == nil
        var cursor = files[url] ?? cachedCursor(url, inode: inode)
        let reset = inode != cursor.inode || size < cursor.offset || (size == cursor.offset && cursor.modified != modified)
        if reset {
            cursor = Cursor(inode: inode)
        }
        if size == cursor.offset && !reset { files[url] = cursor; return (0, isNew) }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: cursor.offset)
        let data = try handle.read(upToCount: min(limit, 2 * 1024 * 1024)) ?? Data()
        for line in cursor.lines.append(data) {
            if let record = ClaudeUsageRecord.decode(line) { cursor.ledger.ingest(record) }
        }
        cursor.offset += UInt64(data.count); cursor.modified = modified
        files[url] = cursor
        do { try cache?.save(.init(inode: inode, offset: cursor.offset-UInt64(cursor.lines.uncommittedByteCount), modified: modified, ledger: cursor.ledger), for: url) }
        catch { cacheError = error.localizedDescription }
        return (data.count, reset || !data.isEmpty)
    }
    private func cachedCursor(_ url: URL, inode: UInt64) -> Cursor {
        guard let saved = try? cache?.load(url) else { return Cursor(inode: inode) }
        return Cursor(inode: saved.inode, offset: saved.offset, modified: saved.modified, ledger: saved.ledger)
    }
}
