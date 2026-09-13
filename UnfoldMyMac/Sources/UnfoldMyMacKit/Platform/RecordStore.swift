import CryptoKit
import Darwin
import Foundation

/// One record per key in a private folder. Keys never reach the file system: names are SHA-256
/// digests, the folder is created mode 0700, writes are atomic, and read-modify-write cycles hold an
/// advisory lock so concurrent hook invocations cannot lose each other's updates.
struct RecordStore: Sendable {
    enum Format: Sendable { case json, propertyList }
    let directory: URL
    var format: Format = .json
    var pathExtension: String { format == .json ? "json" : "plist" }

    static func digest(_ key: String) -> String { digest(Data(key.utf8)) }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func url(for key: String) -> URL { directory.appendingPathComponent(Self.digest(key) + "." + pathExtension) }

    func read<Record: Decodable>(_ type: Record.Type, for key: String) throws -> Record? {
        let url = url(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decode(Record.self, from: Data(contentsOf: url))
    }
    func write<Record: Encodable>(_ record: Record, for key: String) throws {
        try prepareDirectory()
        try encode(record).write(to: url(for: key), options: .atomic)
    }
    /// Serialises writers of one key. `body` receives the stored record (nil when absent or unreadable)
    /// and returns nil to leave the file untouched.
    func update<Record: Codable>(_ type: Record.Type, for key: String, _ body: (Record?) throws -> Record?) throws {
        try prepareDirectory()
        let lock = open(directory.appendingPathComponent(Self.digest(key) + ".lock").path, O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(lock, LOCK_UN); close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        let existing = try? read(Record.self, for: key)
        guard let next = try body(existing) else { return }
        try encode(next).write(to: url(for: key), options: .atomic)
    }
    /// Removes records not modified within `age`. Heartbeat records have no history value.
    func prune(olderThan age: TimeInterval, now: Date = .now) {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for url in urls where url.pathExtension == pathExtension {
            if let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               now.timeIntervalSince(modified) > age { try? FileManager.default.removeItem(at: url) }
        }
    }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    private func encode<Record: Encodable>(_ record: Record) throws -> Data {
        switch format {
        case .json: try JSONEncoder().encode(record)
        case .propertyList: try PropertyListEncoder().encode(record)
        }
    }
    private func decode<Record: Decodable>(_ type: Record.Type, from data: Data) throws -> Record {
        switch format {
        case .json: try JSONDecoder().decode(type, from: data)
        case .propertyList: try PropertyListDecoder().decode(type, from: data)
        }
    }
}
