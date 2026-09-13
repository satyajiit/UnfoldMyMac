import Foundation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

struct FakeUpdateEnvironment: UpdateEnvironmentProbing {
    var bundleURL: URL = URL(fileURLWithPath: "/Applications/UnfoldMyMac.app")
    var verdict: UpdateEligibility = .eligible
    var systemMajorVersion = 26
    var freeSpaceAtInstall: Int64 = 10_000_000_000
    var freeSpaceAtDownload: Int64 = 10_000_000_000
    var installDirectoryWritable = true
    var installedByCurrentUser = true

    func eligibility() async -> UpdateEligibility { verdict }
    func facts(currentVersion: AppVersion) async -> UpdateFacts {
        UpdateFacts(eligibility: verdict, currentVersion: currentVersion, systemMajorVersion: systemMajorVersion,
                    freeSpaceAtInstall: freeSpaceAtInstall, freeSpaceAtDownload: freeSpaceAtDownload,
                    installDirectoryWritable: installDirectoryWritable, installedByCurrentUser: installedByCurrentUser)
    }
}

/// Counts what it was asked for, so a test can prove the updater stayed off the network entirely.
final class FakeReleaseFeed: ReleaseFeedReading, Sendable {
    private let outcome: Mutex<Result<UpdateRelease, UpdateError>>
    let calls = Mutex(0)
    let noteCalls = Mutex(0)

    init(_ outcome: Result<UpdateRelease, UpdateError>) { self.outcome = Mutex(outcome) }
    func set(_ value: Result<UpdateRelease, UpdateError>) { outcome.withLock { $0 = value } }

    func latest() async throws -> UpdateRelease {
        calls.withLock { $0 += 1 }
        return try outcome.withLock { $0 }.get()
    }
    func notes(for release: UpdateRelease) async -> String {
        noteCalls.withLock { $0 += 1 }
        return release.notes
    }
    func checksums(at url: URL) async throws -> String { "" }
}

final class FakeArtifactDownloader: ArtifactDownloading, Sendable {
    let steps: [DownloadEvent]
    let failure: UpdateError?
    let contents: Data

    init(steps: [DownloadEvent] = [.progress(received: 54, expected: 54), .finished],
         failure: UpdateError? = nil, contents: Data = Data("image".utf8)) {
        self.steps = steps; self.failure = failure; self.contents = contents
    }
    func download(_ release: UpdateRelease, to destination: URL,
                  resumeAt resumeData: URL) -> AsyncThrowingStream<DownloadEvent, any Error> {
        AsyncThrowingStream { continuation in
            if let failure { continuation.finish(throwing: failure); return }
            try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? contents.write(to: destination)
            for step in steps { continuation.yield(step) }
            continuation.finish()
        }
    }
}

struct FakeCodeSignatureValidator: CodeSignatureValidating {
    var failure: UpdateError?
    var isRelease = true
    var shortVersion = "1.0.2"
    var minimumSystem = "26.0"

    func validate(_ url: URL, as artifact: SignedArtifact) throws { if let failure { throw failure } }
    func runningApplicationIsRelease() -> Bool { isRelease }
    func securedInfoPlist(at url: URL) throws -> [String: Any] {
        ["CFBundleShortVersionString": shortVersion, "LSMinimumSystemVersion": minimumSystem]
    }
}

/// Hands `body` a real directory laid out like a mounted image, so everything above the mount is
/// exercised against real file-system behaviour without `hdiutil`.
final class FakeDiskImageMounter: DiskImageMounting, Sendable {
    let contents: [String]
    let symlinks: [String]
    let detachFailure: UpdateError?
    let detaches = Mutex(0)

    init(contents: [String] = ["UnfoldMyMac.app"], symlinks: [String] = [], detachFailure: UpdateError? = nil) {  // swiftlint:disable:this line_length
        self.contents = contents; self.symlinks = symlinks; self.detachFailure = detachFailure
    }

    func withMountedImage<T: Sendable>(at image: URL,
                                       _ body: @Sendable (_ mountPoint: URL) async throws -> T) async throws -> T {
        let mount = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mnt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        for name in contents {
            try FileManager.default.createDirectory(at: mount.appendingPathComponent(name),
                                                    withIntermediateDirectories: true)
        }
        for name in symlinks {
            try FileManager.default.createSymbolicLink(at: mount.appendingPathComponent(name),
                                                       withDestinationURL: URL(fileURLWithPath: "/Applications"))
        }
        defer {
            detaches.withLock { $0 += 1 }
            try? FileManager.default.removeItem(at: mount)
        }
        if let detachFailure { _ = try? await body(mount); throw detachFailure }
        return try await body(mount)
    }
}

final class FakeBundleInstaller: BundleInstalling, Sendable {
    let handoffs = Mutex(0)
    let failure: UpdateError?
    init(failure: UpdateError? = nil) { self.failure = failure }
    func handOff(staged: URL, target: URL, version: AppVersion) async throws {
        if let failure { throw failure }
        handoffs.withLock { $0 += 1 }
    }
}

/// Records the argument vector, which is how the tests prove no shell string is ever built.
final class FakeProcessRunner: ProcessRunning, Sendable {
    let invocations = Mutex<[(String, [String])]>([])
    let status: Int32
    init(status: Int32 = 0) { self.status = status }

    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) async throws -> ProcessResult {
        invocations.withLock { $0.append((executable, arguments)) }
        return ProcessResult(status: status, standardOutput: Data(), standardError: Data())
    }
    func spawnDetached(_ executable: String, _ arguments: [String]) throws {
        invocations.withLock { $0.append((executable, arguments)) }
    }
}

@MainActor func makeUpdateModel(store: InMemoryPreferencesStore = InMemoryPreferencesStore(),
                                current: String = "1.0.1",
                                feed: any ReleaseFeedReading,
                                flow: UpdateInstallFlow = UpdateInstallFlow(),
                                installer: any BundleInstalling = FakeBundleInstaller(),
                                environment: any UpdateEnvironmentProbing = FakeUpdateEnvironment(),
                                now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_800_000_000) }) -> UpdateModel {
    UpdateModel(preferences: store, currentVersion: AppVersion(current)!, feed: feed, flow: flow,
                installer: installer, environment: environment, now: now)
}

func makeRelease(_ version: String, size: Int64 = 54, digest: String? = String(repeating: "a", count: 64),
                 minimumSystem: String? = nil, notes: String = "") -> UpdateRelease {
    let parsed = AppVersion(version)!
    return UpdateRelease(version: parsed, assetName: UpdateRelease.expectedAssetName(for: parsed),
                         assetURL: URL(string: "https://github.com/satyajiit/UnfoldMyMac/releases/download/v\(version)/\(UpdateRelease.expectedAssetName(for: parsed))")!,
                         assetSize: size, expectedDigest: digest, minimumSystem: minimumSystem, notes: notes)
}
