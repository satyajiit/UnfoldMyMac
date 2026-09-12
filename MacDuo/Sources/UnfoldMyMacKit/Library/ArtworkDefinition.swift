import Foundation
import UnfoldMyMacCore

/// Content owns metadata and a file; the shared reveal pipeline owns all motion.
struct ArtworkDefinition: Identifiable, Sendable {
    let descriptor: EffectDescriptor
    let imageURL: URL
    var id: EffectID { descriptor.id }
}

enum LibraryAssets {
    static func url(_ name: String, folder: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/\(folder)")
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
        guard let manifest = Bundle.module.url(forResource: "Artworks", withExtension: "json", subdirectory: "Resources/Library") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: manifest))
        return try entries.map { entry in
            guard let image = url(entry.asset, folder: "Artwork") else { throw CocoaError(.fileNoSuchFile) }
            return ArtworkDefinition(descriptor: .init(id: .init(rawValue: entry.id), title: entry.title,
                subtitle: entry.subtitle, detail: entry.detail, symbol: UnfoldMyMacIcon.image.rawValue,
                parameterTitle: "Depth & edge light", renderingLabel: "Image reveal", category: .image,
                tags: entry.tags, author: entry.author, credit: entry.credit, coverURL: image, defaultReveal: entry.reveal), imageURL: image)
        }
    }
}
