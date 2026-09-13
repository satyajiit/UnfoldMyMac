import Foundation
import UnfoldMyMacCore

/// Download, prove, stage. The whole chain between "the user clicked Update" and "a verified copy is
/// sitting beside the old one", with no interface state in it so each step can be tested alone.
struct UpdateInstallFlow: Sendable {
    var downloader: any ArtifactDownloading = URLSessionArtifactDownloader()
    var staging = UpdateStaging()
    var feed: any ReleaseFeedReading = ReleaseFeed()
    var paths = UpdatePaths.live

    /// Returns the staging directory holding the verified application.
    func run(_ release: UpdateRelease, target: URL, systemMajorVersion: Int,
             onProgress: @Sendable @escaping (Int64, Int64) -> Void,
             onVerifying: @Sendable @escaping () -> Void) async throws -> URL {
        let image = try await download(release, onProgress: onProgress)
        onVerifying()
        try await verify(image, release: release)
        return try await staging.stage(image, for: release, over: target, systemMajorVersion: systemMajorVersion)
    }

    private func download(_ release: UpdateRelease,
                          onProgress: @Sendable @escaping (Int64, Int64) -> Void) async throws -> URL {
        let destination = paths.diskImage(for: release)
        // A complete, correct copy from an earlier session costs nothing to reuse.
        if let digest = release.expectedDigest, FileManager.default.fileExists(atPath: destination.path),
           (try? StreamingSHA256.digest(ofFileAt: destination)) == digest {
            return destination
        }
        try paths.prepare()
        for try await event in downloader.download(release, to: destination,
                                                   resumeAt: paths.resumeData(for: release.version)) {
            if case .progress(let received, let expected) = event { onProgress(received, expected) }
        }
        try? FileManager.default.removeItem(at: paths.resumeData(for: release.version))
        return destination
    }

    /// Integrity, not authenticity: the digest travels from the same place the image did, so anyone
    /// able to replace one could replace both. Its worth is failing fast and cheaply on the common
    /// case, which is a damaged download — the signature is what actually decides trust.
    private func verify(_ image: URL, release: UpdateRelease) async throws {
        guard let expected = try await expectedDigest(for: release) else { throw UpdateError.noChecksumPublished }
        let actual: String
        do { actual = try StreamingSHA256.digest(ofFileAt: image) }
        catch is CancellationError { throw CancellationError() }
        catch { throw UpdateError.downloadCouldNotBeSaved }
        guard actual == expected else {
            try? FileManager.default.removeItem(at: image)
            try? FileManager.default.removeItem(at: paths.resumeData(for: release.version))
            throw UpdateError.checksumMismatch
        }
    }

    private func expectedDigest(for release: UpdateRelease) async throws -> String? {
        if let digest = release.expectedDigest { return digest }
        guard let url = release.checksumURL else { return nil }
        let text = try await feed.checksums(at: url)
        return ChecksumManifest.digest(for: release.assetName, in: text)
    }
}
