import Foundation
import UnfoldMyMacCore

/// GitHub's release payload, decoded beside the client that asks for it.
///
/// This is a vendor wire shape, not a domain value: it stays here and is mapped to `UpdateRelease`
/// so nothing downstream has to know what GitHub calls its fields.
struct GitHubRelease: Decodable, Sendable {
    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadURL: URL
        let size: Int64
        let contentType: String

        private enum CodingKeys: String, CodingKey {
            case name, size
            case browserDownloadURL = "browser_download_url"
            case contentType = "content_type"
        }
    }
    let tagName: String
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case body, draft, prerelease, assets
        case tagName = "tag_name"
        case publishedAt = "published_at"
    }

    func release() throws -> UpdateRelease {
        try UpdateRelease.make(tag: tagName, notes: body ?? "", publishedAt: publishedAt,
                               isDraft: draft, isPrerelease: prerelease,
                               assets: assets.map {
                                   ReleaseAsset(name: $0.name, downloadURL: $0.browserDownloadURL,
                                                size: $0.size, contentType: $0.contentType)
                               })
    }
}
