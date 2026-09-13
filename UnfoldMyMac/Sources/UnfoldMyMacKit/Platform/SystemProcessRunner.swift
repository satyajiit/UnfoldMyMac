import Darwin
import Foundation
import UnfoldMyMacCore

/// Spawns a system tool and collects what it wrote.
///
/// Output goes to files rather than pipes on purpose: reading a `Pipe` after `waitUntilExit()`
/// deadlocks as soon as the child writes past the 64 KB buffer, and `hdiutil attach -plist` does.
/// Exit is detected by polling rather than by `terminationHandler`, which is `@Sendable` and would
/// hand back a non-Sendable `Process`. The process never escapes this actor.
actor SystemProcessRunner: ProcessRunning {
    private let directory: URL

    init(directory: URL = AppSupportPaths.updates) { self.directory = directory }

    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) async throws -> ProcessResult {
        guard SystemTool.allowed.contains(executable) else { throw UpdateError.diskImageCouldNotBeOpened }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let stem = directory.appendingPathComponent("run-\(UUID().uuidString)")
        let outURL = stem.appendingPathExtension("out")
        let errURL = stem.appendingPathExtension("err")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: outURL); try? FileManager.default.removeItem(at: errURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        // Our own process is hardened so DYLD_* is already stripped; the child is a plain system tool.
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        let out = try FileHandle(forWritingTo: outURL)
        let err = try FileHandle(forWritingTo: errURL)
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        try process.run()

        let deadline = Date.now.addingTimeInterval(timeout)
        while process.isRunning {
            if Date.now >= deadline { await Self.stop(process); throw UpdateError.timedOut }
            do { try await Task.sleep(for: .milliseconds(25)) } catch {
                await Self.stop(process)
                throw CancellationError()
            }
        }
        try? out.close(); try? err.close()
        let stdout = (try? Data(contentsOf: outURL)) ?? Data()
        let stderr = (try? Data(contentsOf: errURL)) ?? Data()
        // An uncaught signal is not an exit code; report it as a failure rather than as status 0.
        let status = process.terminationReason == .exit ? process.terminationStatus : -1
        return ProcessResult(status: status, standardOutput: stdout, standardError: stderr)
    }

    /// Never orphan a tool: ask politely, then insist.
    private static func stop(_ process: Process) async {
        process.terminate()
        try? await Task.sleep(for: .milliseconds(500))
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
}

extension SystemProcessRunner {
    nonisolated func spawnDetached(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Deliberately not waited on: once this process exits the child is reparented and carries on,
        // which is the entire point of handing the swap to someone else.
    }
}
