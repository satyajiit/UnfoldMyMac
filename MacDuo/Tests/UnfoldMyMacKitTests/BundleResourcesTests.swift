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
    for name in ["Common", "Emblem"] + WallpaperShaderCatalog.bundled.values.flatMap { [$0.resource] + $0.dependencies } {
        #expect(throws: Never.self, "wallpaper shader \(name)") { try BundleResources.shaderSource(name, family: .wallpaper) }
    }
    let artworks = try LibraryAssets.artworks()
    #expect(!artworks.isEmpty)
    for artwork in artworks {
        #expect(FileManager.default.fileExists(atPath: artwork.imageURL.path), "artwork \(artwork.id.rawValue)")
        #expect(artwork.descriptor.coverURL != nil)
    }
    for registration in BuiltInEffects.registrations {
        #expect(registration.descriptor.coverURL != nil, "cover for \(registration.descriptor.id.rawValue)")
    }
    let templates = try #require(BundleResources.wallpaperTemplates)
    let files = try FileManager.default.contentsOfDirectory(at: templates, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
    #expect(files.count >= 8)
    for file in files {
        let template = try JSONDecoder().decode(WallpaperTemplate.self, from: Data(contentsOf: file))
        #expect(WallpaperShaderCatalog.bundled[template.shader] != nil, "\(template.id) names shader \(template.shader)")
        if let emblem = template.emblem { #expect(BundleResources.wallpaperMark(emblem.asset) != nil, "\(template.id) mark \(emblem.asset)") }
        if let image = template.image { #expect(BundleResources.artwork(image) != nil, "\(template.id) image \(image)") }
        if let cover = template.coverImage { #expect(BundleResources.wallpaperCover(cover) != nil, "\(template.id) cover \(cover)") }
    }
}

@Test func bundleResourcesReportMissingFilesByPath() {
    #expect(BundleResources.shader("Nope", family: .effects) == nil)
    #expect(throws: BundleResourcesError.missing("Shaders/Effects/Nope.metal")) { try BundleResources.shaderSource("Nope", family: .effects) }
    #expect(BundleResources.artwork("Nope") == nil && BundleResources.cover("Nope") == nil)
}
