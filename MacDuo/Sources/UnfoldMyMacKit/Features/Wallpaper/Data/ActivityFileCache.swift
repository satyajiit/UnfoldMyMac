import Foundation

private let activityDecoder = JSONDecoder()

/// Small JSON records dropped in a folder by a hook. A file is decoded again only when its modification
/// date changes, so a second-by-second poll costs one directory listing, not a thousand reads.
struct ActivityFileCache<Record: Decodable & Sendable>: Sendable {
    let maximumFileBytes: Int
    let maximumFiles: Int
    let maximumAge: TimeInterval
    private var entries: [URL: (modified: Date, record: Record)] = [:]
    /// Files decoded so far, for tests.
    private(set) var decodes = 0

    init(maximumFileBytes: Int, maximumFiles: Int, maximumAge: TimeInterval = 86_400) {
        self.maximumFileBytes = maximumFileBytes; self.maximumFiles = maximumFiles; self.maximumAge = maximumAge
    }
    mutating func records(in directory: URL, at date: Date) -> [Record] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
        let candidates = files.filter { $0.pathExtension == "json" }.compactMap { url -> (URL, Date)? in
            guard let info = try? url.resourceValues(forKeys: keys), let modified = info.contentModificationDate,
                  (info.fileSize ?? 0) <= maximumFileBytes, date.timeIntervalSince(modified) < maximumAge else { return nil }
            return (url, modified)
        }.sorted { $0.1 > $1.1 }.prefix(maximumFiles)
        let retained = Set(candidates.map(\.0))
        entries = entries.filter { retained.contains($0.key) }
        for (url, modified) in candidates where entries[url]?.modified != modified {
            decodes += 1
            guard let data = try? Data(contentsOf: url), let record = try? activityDecoder.decode(Record.self, from: data) else { continue }
            entries[url] = (modified, record)
        }
        return entries.values.map(\.record)
    }
}
