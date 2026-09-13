import Foundation
import UnfoldMyMacCore

/// The bundled effect content: `Effects.json` for procedural and native designs, `Artworks.json` for image reveals.
/// Both become manifest entries, so the registry, diagnostics and tests see one catalog.
enum EffectAssets {
    static let artworkRenderer = "art-reveal"
    static let artworkParameterTitle = "Depth & edge light"

    static func url(_ name: String, folder: String) -> URL? { BundleResources.image(name, folder: folder) }
    /// A cover declared as `<folder>/<name>` under `Resources/`.
    static func cover(_ path: String) -> URL? {
        let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
        return parts.count == 2 ? url(parts[1], folder: parts[0]) : nil
    }
    static func manifest() throws -> EffectManifest {
        guard let url = BundleResources.effectsManifest else { throw BundleResourcesError.missing("Resources/Effects/Effects.json") }
        return try EffectManifest.decode(try Data(contentsOf: url))
    }
    /// Adding bundled artwork requires only a manifest entry and a PNG file.
    static func artworkEntries() throws -> [EffectManifestEntry] {
        struct Entry: Decodable {
            let id: String, title: String, subtitle: String, detail: String, asset: String
            let author: String, credit: String, tags: [String], reveal: ArtRevealMotion
        }
        guard let manifest = BundleResources.artworkManifest else { throw BundleResourcesError.missing("Resources/Library/Artworks.json") }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: manifest)).map { entry in
            EffectManifestEntry(id: .init(rawValue: entry.id), title: entry.title, subtitle: entry.subtitle, detail: entry.detail,
                symbol: UnfoldMyMacIcon.image.rawValue, category: .image, tags: entry.tags, author: entry.author, credit: entry.credit,
                cover: "Artwork/\(entry.asset)", asset: entry.asset, renderer: artworkRenderer, renderingLabel: "Image reveal",
                parameters: [.strength(title: artworkParameterTitle), .reveal(default: entry.reveal)])
        }
    }
    /// The image an `art-reveal` entry draws; bundled art ships under `Resources/Artwork/`.
    static func artwork(for entry: EffectManifestEntry) throws -> ArtworkDefinition {
        guard let asset = entry.asset, let image = url(asset, folder: "Artwork") else {
            throw BundleResourcesError.missing("Resources/Artwork/\(entry.asset ?? entry.id.rawValue).png")
        }
        return ArtworkDefinition(descriptor: entry.descriptor(coverURL: image), imageURL: image)
    }
    static func artworks() throws -> [ArtworkDefinition] { try artworkEntries().map(artwork(for:)) }
}
