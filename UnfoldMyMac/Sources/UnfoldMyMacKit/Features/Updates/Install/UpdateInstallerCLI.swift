import Darwin
import Foundation
import UnfoldMyMacCore

/// The `--install-update` mode: replaces the old application once the old process is gone.
///
/// Runs from the staged bundle, so it is the new build installing itself. Deliberately synchronous
/// and free of AppKit and of every bundle resource: a lone install path must not depend on anything
/// that could be mid-swap, and it must never touch the window server.
enum UpdateInstallerCLI {
    static func run(_ arguments: [String]) -> Int32 {
        guard let handoffPath = value(of: "--handoff", in: arguments),
              let nonce = value(of: "--nonce", in: arguments) else { return 2 }
        let handoffURL = URL(fileURLWithPath: handoffPath)
        guard var handoff = UpdateHandoff.read(at: handoffURL), handoff.isUsable(nonce: nonce) else { return 2 }

        let target = URL(fileURLWithPath: handoff.target)
        let staged = URL(fileURLWithPath: handoff.staging)
        let stagedApp = staged.appendingPathComponent("\(AppIdentity.name).app")
        // Without this the signed binary would be a general-purpose "move anything over anything".
        guard bundleIdentifier(at: stagedApp) == AppIdentity.bundleIdentifier,
              bundleIdentifier(at: target) == AppIdentity.bundleIdentifier else { return 2 }

        setsid()
        let validator = SecurityCodeSignatureValidator(pinsToRunningIdentity: false)
        // A different process at a different moment: cheap, and it covers a rewrite during the quit.
        guard (try? validator.validate(stagedApp, as: .application)) != nil else {
            finish(&handoff, at: handoffURL, outcome: .rolledBack, reason: UpdateError.signatureRejected.errorDescription)
            try? FileManager.default.removeItem(at: staged)
            reopen(target)
            return 1
        }
        waitForExit(of: handoff.processIdentifier, runningAt: target)

        guard exchange(stagedApp, target) else {
            finish(&handoff, at: handoffURL, outcome: .rolledBack, reason: UpdateError.appMovedDuringInstall.errorDescription)
            try? FileManager.default.removeItem(at: staged)
            reopen(target)
            return 1
        }
        // The exchange is atomic, so a failure here is a verified-bad result rather than a half state:
        // swapping back restores exactly what was there.
        if (try? validator.validate(target, as: .application)) == nil {
            _ = exchange(stagedApp, target)
            finish(&handoff, at: handoffURL, outcome: .rolledBack, reason: UpdateError.updateRolledBack.errorDescription)
            try? FileManager.default.removeItem(at: staged)
            reopen(target)
            return 1
        }
        // `staged` now holds the outgoing version.
        try? FileManager.default.removeItem(at: staged)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: handoffPath).deletingLastPathComponent()
            .appendingPathComponent("v\(handoff.expectedVersion)"))
        finish(&handoff, at: handoffURL, outcome: .installed, reason: nil)
        reopen(target)
        return 0
    }

    /// One syscall, so there is no instant in which the application does not exist, and so undoing it
    /// is the same call again.
    private static func exchange(_ staged: URL, _ target: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: target.path) else {
            return (try? FileManager.default.moveItem(at: staged, to: target)) != nil
        }
        return renamex_np(staged.path, target.path, UInt32(RENAME_SWAP)) == 0
    }

    private static func waitForExit(of pid: Int32, runningAt target: URL) {
        let expected = target.appendingPathComponent("Contents/MacOS/\(AppIdentity.name)").path
        // A recycled identifier belonging to some other process must not be waited on.
        guard pid > 0, processPath(pid) == expected else { return }
        for _ in 0..<600 {
            if kill(pid, 0) != 0 && errno == ESRCH { return }
            usleep(50_000)
        }
    }

    private static func processPath(_ pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer[..<Int(length)], as: UTF8.self)
    }

    private static func bundleIdentifier(at bundle: URL) -> String? {
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = object as? [String: Any] else { return nil }
        return dictionary["CFBundleIdentifier"] as? String
    }

    /// By path, never by name or bundle id: Launch Services keeps its own record of where a bundle
    /// identifier lives and could resolve a different copy than the one just installed.
    private static func reopen(_ target: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: SystemTool.open)
        process.arguments = [target.path]
        try? process.run()
        process.waitUntilExit()
    }

    private static func finish(_ handoff: inout UpdateHandoff, at url: URL, outcome: UpdateHandoff.Outcome, reason: String?) {
        handoff.outcome = outcome
        handoff.reason = reason
        try? handoff.write(to: url)
    }

    private static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.index(after: index) < arguments.endIndex
        else { return nil }
        return arguments[arguments.index(after: index)]
    }
}
