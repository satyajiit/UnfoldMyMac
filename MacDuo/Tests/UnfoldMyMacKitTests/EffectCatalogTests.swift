import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

// Phase 7: the catalog is data; the only Swift registration is the renderer factory table.
@Test @MainActor func everyCatalogEntryHasARendererAndEveryRendererIsUsed() throws {
    let manifest = try EffectAssets.manifest()
    let entries = manifest.effects + (try EffectAssets.artworkEntries())
    for entry in entries { #expect(EffectRendererFactories.factory(for: entry) != nil, "\(entry.id.rawValue) names \(entry.renderer)") }
    let used = Set(entries.map(\.renderer))
    for key in EffectRendererFactories.table.keys { #expect(used.contains(key), "factory \(key) has no catalog entry") }
    #expect(manifest.default == UnfoldMyMacSettings().effect, "A fresh install selects the catalog's default")
    let fallbackEntry = try #require(manifest.effects.first { $0.id == manifest.fallback })
    #expect(manifest.fallback == .veil && !fallbackEntry.capabilities.requiresCapture)
    let registry = EffectRegistry.builtIn()
    #expect(registry.fallback == .veil && registry.reduceTransparencyFallback == .fade)
    #expect(registry.entries.map(\.descriptor.id) == entries.map(\.id), "Catalog order is gallery order")
    let curtains = try #require(registry.entry(for: .curtains)?.descriptor)
    #expect(curtains.parameterTitle == "Fold depth" && curtains.symbol == "theatermasks" && curtains.renderingLabel == "3D velvet")
    let reverie = try #require(registry.entry(for: .reverie)?.descriptor)
    #expect(reverie.defaultReveal == .curved && reverie.parameters.map(\.key) == ["strength", "reveal"])
}

@Test @MainActor func registryResolvesUnknownIDsToTheFallbackAndReportsSkippedRenderers() throws {
    let registry = EffectRegistry.builtIn()
    let unknown = registry.resolve(EffectID(rawValue: "import.gone"))
    #expect(unknown.substituted && unknown.entry.descriptor.id == .veil && !unknown.entry.descriptor.requiresCapture)
    #expect(!registry.resolve(.frost).substituted && registry.entry(for: EffectID(rawValue: "import.gone")) == nil)
    #expect(registry.title(for: EffectID(rawValue: "import.gone")) == "import.gone")
    let orphan = EffectManifestEntry(id: .init(rawValue: "future"), title: "Future", subtitle: "", detail: "", symbol: "circle", category: .glass, tags: ["t"],
        cover: "Covers/Veil", renderer: "metal-pipeline:not-yet", renderingLabel: "?", parameters: [])
    let partial = EffectRegistry(manifestEntries: [orphan] + (try EffectAssets.manifest().effects.filter { $0.id == .veil }))
    #expect(partial.entries.map(\.descriptor.id) == [.veil])
    #expect(partial.diagnostics == ["Effect ‘future’ names the renderer ‘metal-pipeline:not-yet’, which this build does not have."])
    let empty = EffectRegistry(entries: [], fallback: .frost)
    #expect(empty.entries.map(\.descriptor.id) == [.veil] && empty.fallback == .veil && empty.reduceTransparencyFallback == .veil)
    #expect(empty.diagnostics.first?.contains("empty") == true)
}

@Test @MainActor func savedUnknownEffectIsSubstitutedWithANoticeAndRemovalFallsBackToVeil() async throws {
    let store = InMemoryPreferencesStore()
    var saved = UnfoldMyMacSettings(); saved.effect = EffectID(rawValue: "import.gone"); store.settings = saved
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let model = makeModel(store: store, registry: registry, session: session)
    #expect(model.selectedEffect.id == .veil && model.activeEffect.id == .veil)
    #expect(model.libraryMessage?.contains("‘import.gone’ is not installed") == true)
    model.selectEffect(EffectID(rawValue: "also.gone"))
    #expect(model.settings.effect == .veil && model.libraryMessage == "‘also.gone’ is not installed.")

    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let library = ArtworkLibrary(directory: root.appendingPathComponent("library"))
    let full = EffectRegistry.builtIn()
    let withArt = makeModel(registry: full, session: EffectSession(registry: full, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() }), artworkLibrary: library)
    await withArt.importArtwork(at: try imageFixture(in: root))
    let imported = try #require(full.descriptors.first { $0.isImported })
    #expect(withArt.settings.effect == imported.id)
    #expect(withArt.removeArtwork(imported.id))
    #expect(withArt.settings.effect == .veil && full.entry(for: imported.id) == nil)
    #expect(withArt.libraryMessage == "\(imported.title) was removed. Veil is selected instead.")
}

// A new effect that reuses an existing renderer is a manifest entry alone.
@Test @MainActor func aManifestEntryAloneAddsAnEffect() throws {
    let json = Data("""
    {"version":1,"default":"veil","fallback":"veil","reduceTransparencyFallback":"veil","effects":[
      {"id":"veil","title":"Veil","cover":"Covers/Veil","renderer":"native:veil","tags":["Glass"]},
      {"id":"dusk","title":"Dusk","subtitle":"A second shade.","cover":"Covers/Fade","renderer":"native:fade","category":"glass","tags":["Dark"],
       "parameters":[{"key":"strength","title":"Depth","kind":"slider","default":0.5},{"key":"warm","title":"Warm tint","kind":"toggle","default":false}]}]}
    """.utf8)
    let manifest = try EffectManifest.decode(json)
    let registry = EffectRegistry(manifestEntries: manifest.effects, fallback: manifest.fallback, reduceTransparencyFallback: manifest.reduceTransparencyFallback)
    #expect(registry.diagnostics.isEmpty && registry.entries.map(\.descriptor.id.rawValue) == ["veil", "dusk"])
    let dusk = try #require(registry.entry(for: EffectID(rawValue: "dusk")))
    #expect(dusk.descriptor.parameterTitle == "Depth" && dusk.descriptor.parameters.map(\.key) == ["strength", "warm"] && dusk.descriptor.coverURL != nil)
    #expect(dusk.makePipeline == nil, "Native renderers have no GPU pipeline to check")
    let renderer = try dusk.makeRenderer(nil)
    #expect(renderer is NativeEffectRenderer)
    renderer.stop()
}
