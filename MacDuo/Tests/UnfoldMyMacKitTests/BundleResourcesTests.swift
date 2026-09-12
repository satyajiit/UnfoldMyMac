import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Every resource the code asks for by role must exist in the bundle. Runs without a GPU, so CI catches
/// a renamed shader, a missing cover or a template naming an asset that was never added.
@Test @MainActor func everyDeclaredResourceResolves() throws {
    for weight in ["Regular", "Medium", "Bold"] { #expect(BundleResources.font("SpaceGrotesk-\(weight)") != nil, "font \(weight)") }
    #expect(BundleResources.brandLogo != nil)
    #expect(BundleResources.artworkManifest != nil)
    for effect in ["Frost", "Curtains", "ArtReveal", "Current", "Peekaboo"] {
        #expect(throws: Never.self, "effect shader \(effect)") { try BundleResources.shaderSource(effect, family: .effects) }
    }
    for name in ["Common", "Emblem", "RaceCar", "RaceMaterials"] {
        #expect(throws: Never.self, "wallpaper shader \(name)") { try BundleResources.shaderSource(name, family: .wallpaper) }
    }
    #expect(BundleResources.effectsManifest != nil && BundleResources.wallpaperCollection != nil && BundleResources.wallpaperStyle != nil)
    let artworks = try EffectAssets.artworks()
    #expect(!artworks.isEmpty)
    for artwork in artworks {
        #expect(FileManager.default.fileExists(atPath: artwork.imageURL.path), "artwork \(artwork.id.rawValue)")
        #expect(artwork.descriptor.coverURL != nil)
    }
    for entry in try EffectAssets.manifest().effects {
        #expect(EffectAssets.cover(entry.cover) != nil, "cover for \(entry.id.rawValue)")
    }
    let collection = try WallpaperCollection.bundled()
    let loaded = WallpaperTemplateLoader.load(directory: try #require(BundleResources.wallpaperTemplates), context: .init(categories: Set(collection.categories.map(\.id))))
    #expect(loaded.problems.isEmpty && loaded.items.count >= 8)
    for item in loaded.items {
        let template = item.document.template
        #expect(item.document.sourceVersion == WallpaperTemplate.currentVersion && item.assets.folder != nil, "\(template.id) lives in its own folder")
        #expect(item.document.warnings.isEmpty, "\(template.id): \(item.document.warnings)")
        let scene = try #require(template.scene, "\(template.id) owns its scene")
        #expect(item.assets.shader(scene.source) != nil, "\(template.id) scene \(scene.source)")
        for module in scene.dependencies ?? [] { #expect(BundleResources.shader(module, family: .wallpaper) != nil, "\(template.id) module \(module)") }
        if let emblem = template.emblem { #expect(item.assets.mark(emblem.asset) != nil, "\(template.id) mark \(emblem.asset)") }
        if let image = template.image { #expect(item.assets.image(image) != nil, "\(template.id) image \(image)") }
        #expect(template.category != nil && template.order != nil, "\(template.id) is placed in the collection")
    }
    #expect(WallpaperStyleSheet.bundled == .standard)
}

@Test func bundleResourcesReportMissingFilesByPath() {
    #expect(BundleResources.shader("Nope", family: .effects) == nil)
    #expect(throws: BundleResourcesError.missing("Shaders/Effects/Nope.metal")) { try BundleResources.shaderSource("Nope", family: .effects) }
    #expect(BundleResources.artwork("Nope") == nil && BundleResources.image("Nope", folder: "Covers") == nil)
}
