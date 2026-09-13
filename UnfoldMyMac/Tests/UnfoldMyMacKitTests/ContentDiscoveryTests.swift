import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func discoveryCatalogSeparatesScenesAndDeclaresAccurateCapabilities() throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let garden = try #require(registry.templates.first { $0.id == "hinge-garden" })
    #expect(garden.contentCollection == .scenes)
    #expect(Set(garden.contentCapabilities).isSuperset(of: [.lid, .motion, .microphone]))
    #expect(!garden.contentCapabilities.contains(.network))
    let grok = try #require(registry.templates.first { $0.id == "grok-horizon" })
    #expect(grok.metadata?.relatedBrands == ["Grok"])
    #expect(!grok.contentCapabilities.contains(.network) && !grok.contentCapabilities.contains(.publicAPI))
    let github = try #require(registry.templates.first { $0.id == "github-after-hours" })
    #expect(github.contentCapabilities.contains(.network) && github.contentCapabilities.contains(.publicAPI))
    let claude = try #require(registry.templates.first { $0.id == "claude-current" })
    #expect(claude.contentCapabilities.contains(.localFiles) && !claude.contentCapabilities.contains(.publicAPI))
    for template in registry.templates {
        #expect(template.metadata?.isValid == true, Comment(rawValue: template.id))
        #expect(!template.contentAuthors.isEmpty)
        #expect(template.contentAuthors.allSatisfy { $0.publicURL != nil })
        #expect(template.metadata?.sections?.isEmpty == false)
        #expect(BundleResources.image(template.contentCollection.banner, folder: "Discovery") != nil)
    }
    for brand in ["Claude", "Codex", "Grok", "F1", "GTAVI"] { #expect(BundleResources.contentMark(brand) != nil) }
}

@Test @MainActor func discoverySearchCombinesWordsCategoriesTagsAuthorsAndFeatures() throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let garden = try #require(registry.templates.first { $0.id == "hinge-garden" })
    #expect(garden.matchesDiscovery(query: "  garden  MICROPHONE ", category: "nature", tag: "Lid reactive"))
    #expect(!garden.matchesDiscovery(query: "garden", category: "ai"))
    #expect(!garden.matchesDiscovery(query: "garden nonexistent"))
    #expect(!garden.matchesDiscovery(query: "garden", tag: "GitHub"))
    let aurora = try #require(registry.templates.first { $0.id == "aurora-observatory" })
    #expect(aurora.matchesDiscovery(query: "NASA public API"))
}

@Test func editorialMetadataRoundTripsAndLegacyTemplatesRemainCompatible() throws {
    let data = try #require(templateV1Fixtures()["pulse"])
    var old = try WallpaperTemplateSchema.decode(data).template
    #expect(old.metadata == nil && old.contentCollection == .wallpapers)
    #expect(old.contentAuthors == [.unfoldMyMac])
    old.metadata = .init(collection: "scenes", overview: "**A new scene**", sections: [.init(title: "Motion", body: "Moves with you.")],
                         authors: [.unfoldMyMac], relatedBrands: ["Codex"], banner: "Cover", badge: "New")
    let roundTrip = try WallpaperTemplateSchema.decode(JSONEncoder().encode(old)).template
    #expect(roundTrip == old && roundTrip.contentCollection == .scenes)
    old.metadata?.collection = "future-collection"
    #expect(old.contentCollection == .wallpapers, "Unknown collections stay discoverable without breaking rendering")
    old.metadata?.authors = [.init(name: "Creator", url: URL(string: "file:///tmp/private"))]
    #expect(throws: WallpaperError.invalidField("metadata")) { try old.validated() }
    old.metadata = .init(banner: "../outside")
    #expect(throws: WallpaperError.invalidField("metadata")) { try old.validated() }
    old.metadata = .init(relatedBrands: ["Codex", "Codex"])
    #expect(throws: WallpaperError.invalidField("metadata")) { try old.validated() }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func browsingGalleryDoesNotStartPreviewDataOrApplyADesign() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let model = WallpaperModel(preferences: InMemoryPreferencesStore(), environment: FakeSystemEnvironment(), displays: FakeDisplay(),
                               surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(), coverDirectory: directory)
    defer { model.shutdown() }
    model.start(); model.setBrowsing(true); model.select("pulse")
    #expect(model.previewFPS == 0 && model.previewData.snapshot.sources.isEmpty)
    #expect(!model.enabled && model.activePipeline == nil)
    model.setPreviewVisible(true)
    try await settle { model.previewData.snapshot.sources["mac"] != nil }
    #expect(model.previewFPS > 0 && !model.enabled)
    model.setPreviewVisible(false)
    #expect(model.previewData.snapshot.sources.isEmpty && model.previewFPS == 0)
    model.select("aurora-observatory")
    #expect(model.previewData.snapshot.sources.isEmpty && !model.enabled)
}

@Test @MainActor func effectCatalogCarriesEditorialCreditsIntoItsDescriptor() throws {
    let url = try #require(BundleResources.effectsManifest)
    let manifest = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var entry = try #require((manifest["effects"] as? [[String: Any]])?.first)
    entry["metadata"] = ["version": 1, "overview": "A frosted close.",
                         "authors": [["name": "Guest creator", "url": "https://example.com/creator"]]]
    let decoded = try JSONDecoder().decode(EffectManifestEntry.self, from: JSONSerialization.data(withJSONObject: entry))
    #expect(decoded.isValid)
    #expect(decoded.descriptor(coverURL: nil).contentAuthors.first?.name == "Guest creator")
    #expect(decoded.descriptor(coverURL: nil).metadata?.overview == "A frosted close.")
}

@Test @MainActor func coverQueueCanCancelInvalidateAndRestartBetweenYields() async throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let template = try #require(registry.templates.first { registry.assets(for: $0.id).cover(for: $0) != nil })
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = WallpaperCoverStore(factory: nil, directory: directory)
    for _ in 0..<12 {
        store.request([template], assets: registry.assets(for:))
        await Task.yield()
        store.cancel(); store.invalidate(template.id)
    }
    store.request([template], assets: registry.assets(for:))
    try await settle { store.images[template.id] != nil }
    #expect(store.rendered == 0)
    store.cancel()
}
