import Foundation
import UnfoldMyMacCore

enum LibraryAssets {
    static func url(_ name: String, folder: String) -> URL? {
        BundleResources.image(name, folder: folder)
    }

    /// Adding bundled artwork requires only a manifest entry and a PNG file.
    static func artworks() throws -> [ArtworkDefinition] {
        struct Entry: Decodable {
            let id: String
            let title: String
            let subtitle: String
            let detail: String
            let asset: String
            let author: String
            let credit: String
            let tags: [String]
            let reveal: ArtRevealMotion
        }
        guard let manifest = BundleResources.artworkManifest else { throw BundleResourcesError.missing("Resources/Library/Artworks.json") }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: manifest))
        return try entries.map { entry in
            guard let image = url(entry.asset, folder: "Artwork") else { throw BundleResourcesError.missing("Resources/Artwork/\(entry.asset).png") }
            return ArtworkDefinition(descriptor: .init(id: .init(rawValue: entry.id), title: entry.title,
                subtitle: entry.subtitle, detail: entry.detail, symbol: UnfoldMyMacIcon.image.rawValue,
                parameterTitle: "Depth & edge light", renderingLabel: "Image reveal", category: .image,
                tags: entry.tags, author: entry.author, credit: entry.credit, coverURL: image, defaultReveal: entry.reveal), imageURL: image)
        }
    }
}
