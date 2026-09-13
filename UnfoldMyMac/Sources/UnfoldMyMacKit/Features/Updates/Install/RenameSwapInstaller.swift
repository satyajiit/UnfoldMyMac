import Darwin
import Foundation
import UnfoldMyMacCore

/// Hands the swap to the newly staged application's own executable.
///
/// Not a shell script: that would be unsigned code, in a directory any other application can write
/// to, running at the one moment this app is being replaced. The staged bundle is intact and already
/// signature-checked, so running its binary keeps the installer inside the same trust boundary as
/// the app itself — and after the exchange that bundle *is* the installed app, so the running
/// helper never loses the ground under it.
struct RenameSwapInstaller: BundleInstalling {
    var runner: any ProcessRunning = SystemProcessRunner()
    var paths = UpdatePaths.live

    func handOff(staged: URL, target: URL, version: AppVersion) async throws {
        try Self.assertSameVolume(staged, target)
        let executable = staged.appendingPathComponent("Contents/MacOS/\(AppIdentity.name)")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw UpdateError.diskImageLayoutUnexpected
        }
        let handoff = UpdateHandoff(outcome: .pending, target: target.path, staging: staged.path,
                                    expectedVersion: version.description, nonce: UUID().uuidString,
                                    processIdentifier: ProcessInfo.processInfo.processIdentifier,
                                    createdAt: .now)
        try handoff.write(to: paths.handoff)
        try runner.spawnDetached(executable.path,
                                 ["--install-update", "--handoff", paths.handoff.path, "--nonce", handoff.nonce])
    }

    /// The exchange is a rename, and a rename cannot cross volumes. Staging is created beside the
    /// target precisely so this holds; assert it rather than assume it.
    static func assertSameVolume(_ left: URL, _ right: URL) throws {
        guard let a = volume(of: left), let b = volume(of: right), a.isEqual(b) else {
            throw UpdateError.stagingVolumeMismatch
        }
    }

    /// Walks up to the nearest directory that exists: a path yet to be created has no volume of its
    /// own, but the folder it will live in does.
    private static func volume(of url: URL) -> (any NSCopying & NSSecureCoding & NSObjectProtocol)? {
        var probe = url
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe = probe.deletingLastPathComponent()
        }
        return try? probe.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
    }
}
