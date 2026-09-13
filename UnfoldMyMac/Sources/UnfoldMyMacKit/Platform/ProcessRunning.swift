import Foundation

struct ProcessResult: Sendable {
    let status: Int32
    let standardOutput: Data
    let standardError: Data
    var succeeded: Bool { status == 0 }
    var output: String { String(decoding: standardOutput, as: UTF8.self) }
}

/// Runs one system tool. The only seam in the app that starts another process.
///
/// Callers pass an absolute path and an argument vector; there is no shell, no `PATH` lookup and no
/// string interpolation anywhere on this path, so a file name containing a space or a quote is data
/// rather than syntax. The fake records the vector, which is how the tests prove that stays true.
protocol ProcessRunning: Sendable {
    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) async throws -> ProcessResult
    /// Starts a tool and returns at once, for the installer handoff that has to outlive this process.
    /// The only caller passes the executable of a bundle whose Developer ID signature it has just
    /// checked, which is why this one is not restricted to the system tools below.
    func spawnDetached(_ executable: String, _ arguments: [String]) throws
}

extension ProcessRunning {
    func run(_ executable: String, _ arguments: [String]) async throws -> ProcessResult {
        try await run(executable, arguments, timeout: 120)
    }
}

/// The three tools the updater is allowed to start. Nothing else, ever.
enum SystemTool {
    static let diskImage = "/usr/bin/hdiutil"
    static let copy = "/usr/bin/ditto"
    static let open = "/usr/bin/open"
    static let allowed: Set<String> = [diskImage, copy, open]
}
