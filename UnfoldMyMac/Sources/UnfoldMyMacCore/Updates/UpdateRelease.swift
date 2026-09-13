import Foundation

/// One published asset, described without reference to whichever service listed it.
public struct ReleaseAsset: Equatable, Sendable {
    public let name: String
    public let downloadURL: URL
    public let size: Int64
    public let contentType: String

    public init(name: String, downloadURL: URL, size: Int64, contentType: String) {
        self.name = name; self.downloadURL = downloadURL; self.size = size; self.contentType = contentType
    }
}

/// A release the app could install: the domain value the state machine and the UI see.
///
/// Deliberately not the shape GitHub returns. The vendor payload is decoded next to its client and
/// mapped here, so everything downstream is testable without a network stub.
public struct UpdateRelease: Equatable, Sendable {
    public var version: AppVersion
    public var assetName: String
    public var assetURL: URL
    /// Zero when the manifest did not state a size; the download still checks what the server reports.
    public var assetSize: Int64
    /// Known up front from `release.json`. Nil means the digest must be read from `SHA256SUMS`.
    public var expectedDigest: String?
    public var checksumURL: URL?
    /// The major macOS version this build needs, when the manifest said. Nil means unknown.
    public var minimumSystem: String?
    public var notes: String
    public var publishedAt: Date?

    public init(version: AppVersion, assetName: String, assetURL: URL, assetSize: Int64 = 0,
                expectedDigest: String? = nil, checksumURL: URL? = nil, minimumSystem: String? = nil,
                notes: String = "", publishedAt: Date? = nil) {
        self.version = version; self.assetName = assetName; self.assetURL = assetURL; self.assetSize = assetSize
        self.expectedDigest = expectedDigest; self.checksumURL = checksumURL; self.minimumSystem = minimumSystem
        self.notes = notes; self.publishedAt = publishedAt
    }

    public static let checksumAssetName = "SHA256SUMS"
    public static let diskImageContentType = "application/x-apple-diskimage"

    /// The disk image a release of `version` must publish. A release whose asset is named anything
    /// else was cut wrongly, and is refused before a byte is downloaded.
    public static func expectedAssetName(for version: AppVersion) -> String {
        "\(AppIdentity.name)-\(version).dmg"
    }

    /// Builds the domain value from a listing, refusing anything the release script would not produce.
    public static func make(tag: String, notes: String, publishedAt: Date?, isDraft: Bool, isPrerelease: Bool,
                            assets: [ReleaseAsset]) throws -> UpdateRelease {
        guard !isDraft, !isPrerelease else { throw UpdateError.releaseHasNoDownload }
        guard let version = AppVersion(tag) else { throw UpdateError.releaseVersionMismatch }
        // Gated twice: the listing's own flag, and the tag itself. Releases are cut by hand.
        guard !version.isPrerelease else { throw UpdateError.releaseHasNoDownload }

        let images = assets.filter { $0.name.hasSuffix(".dmg") }
        guard images.count == 1, let image = images.first else { throw UpdateError.releaseHasNoDownload }
        guard image.contentType == diskImageContentType else { throw UpdateError.releaseVersionMismatch }
        guard image.name == expectedAssetName(for: version) else { throw UpdateError.releaseVersionMismatch }
        try validate(image.downloadURL)

        guard let sums = assets.first(where: { $0.name == checksumAssetName }) else { throw UpdateError.noChecksumPublished }
        try validate(sums.downloadURL)

        return UpdateRelease(version: version, assetName: image.name, assetURL: image.downloadURL,
                             assetSize: image.size, checksumURL: sums.downloadURL,
                             notes: notes, publishedAt: publishedAt)
    }

    /// Only the origin we publish from may start a download. Redirects are followed afterwards and are
    /// not pinned — the digest and the signature are what actually gate the install.
    public static func validate(_ url: URL) throws {
        guard url.scheme == "https", let host = url.host(),
              host == "github.com" || host.hasSuffix(".github.com") else { throw UpdateError.unexpectedRedirect }
    }
}
