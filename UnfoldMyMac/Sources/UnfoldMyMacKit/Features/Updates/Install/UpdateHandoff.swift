import Foundation
import UnfoldMyMacCore

/// What the quitting app tells the installer, and what the installer leaves behind for the next launch.
///
/// The file is the whole reporting channel. By the time an install fails the process that started it
/// is gone, so there is nobody to show an alert — the next launch reads this instead, which is the
/// same "errors are state" rule the rest of the app follows.
struct UpdateHandoff: Codable, Sendable, Equatable {
    enum Outcome: String, Codable, Sendable {
        case pending, installed, rolledBack
    }
    var outcome: Outcome
    var target: String
    var staging: String
    var expectedVersion: String
    var nonce: String
    var processIdentifier: Int32
    var createdAt: Date
    var reason: String?

    /// A stale or forged handoff must not turn a signed binary into a general-purpose mover.
    static let validity: TimeInterval = 300

    func isUsable(now: Date = .now, nonce expected: String) -> Bool {
        outcome == .pending && self.nonce == expected
            && now.timeIntervalSince(createdAt) < Self.validity && now.timeIntervalSince(createdAt) > -60
    }

    static func read(at url: URL) -> UpdateHandoff? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UpdateHandoff.self, from: data)
    }
    func write(to url: URL) throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try encoder.encode(self).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
