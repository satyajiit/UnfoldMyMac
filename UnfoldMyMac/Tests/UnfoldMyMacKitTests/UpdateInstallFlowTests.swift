import CryptoKit
import Foundation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private func temporaryRoot() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("updates-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

@Test func aDownloadThatDoesNotMatchItsChecksumIsDeletedAndNeverInstalled() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = UpdatePaths(root: root)
    // The published digest says one thing and the bytes say another: the only safe move is to bin it.
    let release = makeRelease("1.0.2", digest: String(repeating: "b", count: 64))
    let flow = UpdateInstallFlow(downloader: FakeArtifactDownloader(contents: Data("not the release".utf8)),
                                 feed: FakeReleaseFeed(.failure(.offline)), paths: paths)

    await #expect(throws: UpdateError.checksumMismatch) {
        try await flow.run(release, target: root.appendingPathComponent("UnfoldMyMac.app"),
                           systemMajorVersion: 26, onProgress: { _, _ in }, onVerifying: {})
    }
    #expect(!FileManager.default.fileExists(atPath: paths.diskImage(for: release).path),
            "A file that failed its checksum must not be left where a retry could reuse it")
    #expect(!FileManager.default.fileExists(atPath: paths.resumeData(for: release.version).path),
            "The resume blob points at the same bad transfer and has to go with it")
}

@Test func progressIsReportedAndTheImageLandsWhereItWasAskedFor() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = UpdatePaths(root: root)
    let body = Data("a real disk image".utf8)
    let release = makeRelease("1.0.2", digest: digest(body))
    let target = root.appendingPathComponent("UnfoldMyMac.app")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

    let flow = UpdateInstallFlow(downloader: FakeArtifactDownloader(contents: body),
                                 staging: UpdateStaging(mounter: FakeDiskImageMounter(),
                                                        signatures: FakeCodeSignatureValidator(),
                                                        runner: FakeProcessRunner(), paths: paths),
                                 feed: FakeReleaseFeed(.failure(.offline)), paths: paths)
    let samples = Mutex<[Int64]>([])
    let verified = Mutex(false)
    let staged = try await flow.run(release, target: target, systemMajorVersion: 26,
                                    onProgress: { received, _ in samples.withLock { $0.append(received) } },
                                    onVerifying: { verified.withLock { $0 = true } })
    #expect(samples.withLock { $0 } == [54], "Progress has to reach the interface, not just the network layer")
    #expect(verified.withLock { $0 }, "The sheet says what it is doing while it proves the download")
    #expect(staged.lastPathComponent.hasPrefix(".\(AppIdentity.name)-update-"))
    #expect(staged.deletingLastPathComponent() == target.deletingLastPathComponent(),
            "Staging sits beside the target so the exchange never crosses a volume")
}

@Test func acompleteDownloadFromAnEarlierSessionIsReusedRatherThanFetchedAgain() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = UpdatePaths(root: root)
    let body = Data("already here".utf8)
    let release = makeRelease("1.0.2", digest: digest(body))
    try FileManager.default.createDirectory(at: paths.downloadDirectory(for: release.version),
                                            withIntermediateDirectories: true)
    try body.write(to: paths.diskImage(for: release))

    let target = root.appendingPathComponent("UnfoldMyMac.app")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    // A downloader that would fail if it were ever asked to run.
    let flow = UpdateInstallFlow(downloader: FakeArtifactDownloader(failure: .offline),
                                 staging: UpdateStaging(mounter: FakeDiskImageMounter(),
                                                        signatures: FakeCodeSignatureValidator(),
                                                        runner: FakeProcessRunner(), paths: paths),
                                 feed: FakeReleaseFeed(.failure(.offline)), paths: paths)
    _ = try await flow.run(release, target: target, systemMajorVersion: 26, onProgress: { _, _ in }, onVerifying: {})
}

@Test func anImageThatIsNotSignedByUsIsRefusedBeforeItIsEverMounted() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = UpdatePaths(root: root)
    let body = Data("tampered".utf8)
    let release = makeRelease("1.0.2", digest: digest(body))
    let mounter = FakeDiskImageMounter()
    let staging = UpdateStaging(mounter: mounter, signatures: FakeCodeSignatureValidator(failure: .signatureRejected),
                                runner: FakeProcessRunner(), paths: paths)
    let flow = UpdateInstallFlow(downloader: FakeArtifactDownloader(contents: body),
                                 staging: staging, feed: FakeReleaseFeed(.failure(.offline)), paths: paths)

    await #expect(throws: UpdateError.signatureRejected) {
        try await flow.run(release, target: root.appendingPathComponent("UnfoldMyMac.app"),
                           systemMajorVersion: 26, onProgress: { _, _ in }, onVerifying: {})
    }
    #expect(mounter.detaches.withLock { $0 } == 0,
            "Attaching hands an unverified image to a kernel filesystem driver, so the signature comes first")
}

@Test func anUpdateNeedingANewerMacOSIsRefusedFromTheImagesOwnSignedPlist() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = UpdatePaths(root: root)
    let body = Data("future build".utf8)
    let release = makeRelease("1.0.2", digest: digest(body))
    let target = root.appendingPathComponent("UnfoldMyMac.app")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    let signatures = FakeCodeSignatureValidator(shortVersion: "1.0.2", minimumSystem: "27.0")
    let flow = UpdateInstallFlow(downloader: FakeArtifactDownloader(contents: body),
                                 staging: UpdateStaging(mounter: FakeDiskImageMounter(), signatures: signatures,
                                                        runner: FakeProcessRunner(), paths: paths),
                                 feed: FakeReleaseFeed(.failure(.offline)), paths: paths)
    await #expect(throws: UpdateError.needsNewerSystem("27")) {
        try await flow.run(release, target: target, systemMajorVersion: 26,
                           onProgress: { _, _ in }, onVerifying: {})
    }
}
