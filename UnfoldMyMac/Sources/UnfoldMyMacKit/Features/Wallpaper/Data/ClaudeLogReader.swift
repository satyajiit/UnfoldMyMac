import Foundation
import UnfoldMyMacCore

/// A bounded tail per file, merged into one ledger as records arrive. Appended records join the ledger
/// incrementally; only a rotated, truncated or deleted file forces a rebuild from the per-file ledgers (P5).
struct ClaudeLogReader {
    private struct Cursor {
        var inode: UInt64
        var offset: UInt64 = 0
        var modified: Date = .distantPast
        var saved: Date = .distantPast
        var savedOffset: UInt64 = 0
        var lines = WallpaperJSONLines()
        var ledger = ClaudeUsageLedger()
    }
    static let discoveryInterval: TimeInterval = 10
    static let cacheWriteInterval: TimeInterval = 5
    static let chunk = 2 * 1024 * 1024
    static let maximumRecords = 1_000_000
    private var files: [URL: Cursor] = [:]
    private var sizes: [URL: UInt64] = [:]
    private var ordered: [URL] = []
    private var recent: [URL] = []
    private var nextFile = 0
    private var discovered: Date = .distantPast
    private var rebuild = false
    private let cache: ClaudeLogCache?
    private let readBudget: Int
    private(set) var ledger = ClaudeUsageLedger()
    private(set) var indexing = false
    private(set) var progress = 0.0
    private(set) var cacheError: String?
    /// Cache files written so far; a warm reader writes once per file plus one per interval while it grows.
    private(set) var cacheWrites = 0
    init(cacheDirectory: URL? = nil, readBudget: Int = 32*1024*1024) {
        cache = cacheDirectory.map { ClaudeLogCache(directory: $0) }; self.readBudget = readBudget
    }

    mutating func refresh(root: URL, at date: Date) throws {
        if date.timeIntervalSince(discovered) >= Self.discoveryInterval { try discover(root, at: date) }
        var budget = readBudget
        for url in recent where files[url] != nil {
            try Task.checkCancellation()
            budget -= try consume(url, limit: min(budget, Self.chunk), at: date)
            if budget <= 0 { break }
        }
        var examined = 0
        while examined < ordered.count && budget > 0 {
            try Task.checkCancellation()
            let url = ordered[nextFile % ordered.count]
            nextFile = (nextFile + 1) % ordered.count; examined += 1
            budget -= try consume(url, limit: budget, at: date)
        }
        let total = sizes.values.reduce(UInt64(0), +)
        let consumed = files.values.reduce(UInt64(0)) { $0 + $1.offset }
        progress = total == 0 ? 1 : min(1, Double(consumed)/Double(total))
        indexing = consumed < total
        if rebuild {
            var combined = ClaudeUsageLedger()
            for cursor in files.values { for record in cursor.ledger.records.values { combined.ingest(record) } }
            ledger = combined; rebuild = false
        }
        guard ledger.records.count <= Self.maximumRecords else {
            throw WallpaperError.unavailable("This log folder is too large. Choose a smaller Claude project folder.")
        }
    }
    /// One directory walk every ten seconds reads sizes and dates for every file, so progress needs no further stat calls.
    private mutating func discover(_ root: URL, at date: Date) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WallpaperError.unavailable("Claude logs were not found. Choose your Claude projects folder in Data sources.")
        }
        var failure: Error?
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles], errorHandler: { _, error in failure = error; return false }) else {
            throw CocoaError(.fileReadNoPermission)
        }
        var found: [(url: URL, modified: Date, size: UInt64)] = []
        for case let url as URL in enumerator {
            let properties = try url.resourceValues(forKeys: keys)
            if properties.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            guard properties.isRegularFile == true, url.pathExtension == "jsonl" else { continue }
            found.append((url, properties.contentModificationDate ?? .distantPast, UInt64(properties.fileSize ?? 0)))
            guard found.count <= 50_000 else { throw WallpaperError.unavailable("More than 50,000 logs found. Choose a smaller Claude project folder.") }
        }
        if let failure { throw failure }
        found.sort { $0.modified > $1.modified }
        let remaining = Set(found.map(\.url))
        if files.keys.contains(where: { !remaining.contains($0) }) { rebuild = true }
        files = files.filter { remaining.contains($0.key) }
        sizes = Dictionary(found.map { ($0.url, $0.size) }, uniquingKeysWith: { first, _ in first })
        ordered = found.map(\.url); discovered = date
        recent = found.prefix(32).filter { date.timeIntervalSince($0.modified) < 300 }.map(\.url)
    }
    private mutating func consume(_ url: URL, limit: Int, at date: Date) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        let modified = attrs[.modificationDate] as? Date ?? .distantPast
        sizes[url] = size
        var cursor = files[url] ?? cachedCursor(url, inode: inode, at: date)
        if inode != cursor.inode || size < cursor.offset || (size == cursor.offset && cursor.modified != modified) {
            cursor = Cursor(inode: inode); rebuild = true
        }
        if size == cursor.offset { files[url] = cursor; return 0 }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: cursor.offset)
        let data = try handle.read(upToCount: min(limit, Self.chunk)) ?? Data()
        for line in cursor.lines.append(data) {
            guard let record = ClaudeUsageRecord.decode(line) else { continue }
            cursor.ledger.ingest(record); ledger.ingest(record)
        }
        cursor.offset += UInt64(data.count); cursor.modified = modified
        let committed = cursor.offset - UInt64(cursor.lines.uncommittedByteCount)
        if committed != cursor.savedOffset, date.timeIntervalSince(cursor.saved) >= Self.cacheWriteInterval {
            do {
                try cache?.save(.init(inode: inode, offset: committed, modified: modified, ledger: cursor.ledger), for: url)
                cursor.saved = date; cursor.savedOffset = committed; cacheWrites += cache == nil ? 0 : 1
            } catch { cacheError = error.localizedDescription }
        }
        files[url] = cursor
        return data.count
    }
    /// A cached tail joins the ledger at once; the file is read on from where the cache stopped.
    private mutating func cachedCursor(_ url: URL, inode: UInt64, at date: Date) -> Cursor {
        guard let saved = try? cache?.load(url) else { return Cursor(inode: inode) }
        for record in saved.ledger.records.values { ledger.ingest(record) }
        return Cursor(inode: saved.inode, offset: saved.offset, modified: saved.modified, saved: date, savedOffset: saved.offset, ledger: saved.ledger)
    }
}
