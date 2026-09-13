import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true) }

// Phase 7: the version 1 documents every template shipped as decode to the same scene as its version 2 folder.
@Test @MainActor func version1FixturesMigrateToTheBundledVersion2Templates() throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let fixtures = try templateV1Fixtures()
    #expect(Set(fixtures.keys).isSubset(of: Set(registry.templates.map(\.id))))
    #expect(fixtures.count == 10, "The ten published v1 templates retain migration coverage")
    for (id, data) in fixtures {
        let migrated = try WallpaperTemplateSchema.decode(data, context: registry.context)
        #expect(migrated.sourceVersion == 1 && migrated.template.version == 2, Comment(rawValue: id))
        var bundled = try #require(registry.templates.first { $0.id == id }, Comment(rawValue: id))
        // Version 2 adds placement, credit and the scene block; the rest is byte-for-byte the version 1 content.
        bundled.category = nil; bundled.order = nil; bundled.credit = nil; bundled.scene = nil; bundled.metadata = nil
        var old = migrated.template; old.coverImage = nil; old.shader = bundled.shader
        #expect(old == bundled, Comment(rawValue: id))
        #expect(migrated.warnings.filter { $0.code != .lowContrast }.isEmpty, Comment(rawValue: "\(id): \(migrated.warnings)"))
    }
    #expect(registry.templates.map(\.order!) == registry.templates.map(\.order!).sorted(), "Folders load in declared order")
    #expect(registry.collection.sections(registry.templates).allSatisfy { $0.category != WallpaperCollection.other })
}

@Test @MainActor func folderDiscoveryOrdersByOrderAcceptsFlatFilesAndReportsProblems() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fixtures = try templateV1Fixtures()
    func write(_ id: String, to path: String, mutate: ((inout [String: Any]) -> Void)? = nil) throws {
        let data = try #require(fixtures[id])
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        mutate?(&object)
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
    }
    try write("pulse", to: "zzz-last/template.json") { $0["order"] = 5 }
    try write("daydream", to: "aaa-first/template.json") { $0["order"] = 50 }
    try write("lights-out", to: "flat.json")
    try write("grok-horizon", to: "broken/template.json") { $0["reactiveMetric"] = "energy" }
    try Data("{".utf8).write(to: root.appendingPathComponent("garbage.json"))
    try FileManager.default.createDirectory(at: root.appendingPathComponent("marks-only"), withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: root.appendingPathComponent("Collection.json"))
    let loaded = WallpaperTemplateLoader.load(directory: root, context: .init())
    #expect(loaded.items.map(\.document.template.id) == ["pulse", "daydream", "lights-out"], "order first, then unordered by name")
    #expect(loaded.items.map { $0.assets.folder != nil } == [true, true, false])
    #expect(loaded.problems.map(\.name) == ["broken", "garbage.json"])
    #expect(loaded.problems[0].error as? WallpaperError == .invalidField("reactiveMetric"))
    #expect(loaded.problems[1].error as? WallpaperError == .invalidTemplate)
}

@Test @MainActor func importedTemplatesKeepTheirBytesRenameThroughTheIndexAndRejectOwnScenes() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let fixtures = try templateV1Fixtures()
    let pulse = try #require(fixtures["pulse"])
    var object = try #require(JSONSerialization.jsonObject(with: pulse) as? [String: Any])
    object["id"] = "my-pulse"; object["title"] = "My Pulse"; object["futureField"] = ["kept": true]
    let source = root.appendingPathComponent("My Pulse.json")
    let bytes = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try bytes.write(to: source)
    let library = WallpaperTemplateLibrary(directory: root.appendingPathComponent("Templates"))
    let catalog = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, library: library)
    var validated: [String] = []
    let imported = try registry.importTemplate(source) { validated.append($0.id) }
    #expect(validated == ["my-pulse"] && imported.shader == "pulse" && registry.isImported("my-pulse") && !registry.isImported("pulse"))
    let record = try #require(library.records.first)
    #expect(try library.data(for: record) == bytes, "The original document is stored unchanged, unknown fields included")
    try registry.rename("my-pulse", title: "  Renamed  ")
    #expect(registry.templates.first { $0.id == "my-pulse" }?.title == "Renamed" && library.records[0].title == "Renamed")
    #expect(try library.data(for: record) == bytes, "Renaming never rewrites the file")
    let reloaded = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), library: WallpaperTemplateLibrary(directory: library.directory))
    #expect(reloaded.templates.first { $0.id == "my-pulse" }?.title == "Renamed")
    #expect(throws: WallpaperError.duplicateID("my-pulse")) { try registry.importTemplate(source) { _ in } }
    object["scene"] = ["source": "Scene.metal", "fragment": "f"]; object["id"] = "sneaky"; object.removeValue(forKey: "shader")
    let sneaky = root.appendingPathComponent("sneaky.json")
    try JSONSerialization.data(withJSONObject: object).write(to: sneaky)
    #expect(throws: WallpaperError.invalidField("scene")) { try registry.importTemplate(sneaky) { _ in } }
    object["scene"] = nil; object["shader"] = "nope"
    try JSONSerialization.data(withJSONObject: object).write(to: sneaky)
    #expect(throws: WallpaperError.missingShader("nope")) { try registry.importTemplate(sneaky) { _ in } }
    #expect(library.records.count == 1)
    try registry.remove("my-pulse")
    #expect(library.records.isEmpty && !registry.templates.contains { $0.id == "my-pulse" })
    #expect(!FileManager.default.fileExists(atPath: library.directory.appendingPathComponent(record.filename).path))
}

@Test @MainActor func preIndexTemplateFilesAreIndexedOnce() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let fixtures = try templateV1Fixtures()
    let pulse = try #require(fixtures["pulse"])
    var object = try #require(JSONSerialization.jsonObject(with: pulse) as? [String: Any])
    object["id"] = "legacy-import"
    let id = UUID()
    try JSONSerialization.data(withJSONObject: object).write(to: root.appendingPathComponent(id.uuidString + ".json"))
    try Data("junk".utf8).write(to: root.appendingPathComponent("notes.json"))
    let library = WallpaperTemplateLibrary(directory: root)
    #expect(library.records == [ImportedTemplate(id: id, templateID: "legacy-import", title: nil)] && library.loadError == nil)
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("library.json").path))
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), library: WallpaperTemplateLibrary(directory: root))
    #expect(registry.isImported("legacy-import") && registry.templates.contains { $0.id == "legacy-import" })
    try Data("broken".utf8).write(to: root.appendingPathComponent("library.json"))
    let corrupt = WallpaperTemplateLibrary(directory: root)
    #expect(corrupt.loadError != nil && corrupt.records.isEmpty)
    #expect(throws: WallpaperError.self) { try corrupt.add(Data("{}".utf8), template: registry.templates[0]) }
}

@Test @MainActor func sceneParametersPackIntoUniformsAndSmoothingFollowsTheTemplate() throws {
    let declared = [WallpaperSceneParameter(key: "spin", default: 0.5, minimum: 0, maximum: 1), .init(key: "glow", default: 2), .init(key: "a", default: 1),
                    .init(key: "b", default: 1), .init(key: "c", default: 1), .init(key: "d", default: 1), .init(key: "e", default: 1), .init(key: "f", default: 7)]
    let packed = WallpaperPipeline.parameters(declared, overrides: ["spin": 9, "glow": -3, "unknown": 1])
    #expect(packed.0 == SIMD4(1, -3, 1, 1) && packed.1 == SIMD4(1, 1, 1, 7), "Declaration order, overrides clamped to declared bounds, unknown keys ignored")
    let fixtures = try templateV1Fixtures()
    let pulse = try #require(fixtures["pulse"])
    var object = try #require(JSONSerialization.jsonObject(with: pulse) as? [String: Any])
    object["reactiveSmoothing"] = 8; object["reduceMotionPose"] = ["time": 2.5, "energy": 0.1]
    object["channels"] = [["metric": "mac.memory", "scale": 100, "smoothing": 1], ["metric": "mac.battery", "scale": 100]]
    let template = try WallpaperTemplateSchema.decode(try JSONSerialization.data(withJSONObject: object)).template
    var smoother = WallpaperFrameSmoother(template: template)
    #expect(smoother.rate == 8 && smoother.channelRates == SIMD4(1, 8, 8, 8) && smoother.stillTime == 2.5)
    smoother.setTargets(energy: 1, channels: SIMD4(1, 1, 0, 0), grid: nil)
    let moving = smoother.advance(delta: 0.25, animating: true)
    #expect(moving.energy > 0.8 && moving.channels[0] < moving.channels[1], "A slower channel lags the template rate")
    let still = smoother.advance(delta: 0.25, animating: false)
    #expect(still.time == 2.5 && still.energy == 1 && still.channels == SIMD4(1, 1, 0, 0), "Reduce Motion holds the declared time with live data")
    #expect(WallpaperFrame(pose: .init(time: 3, energy: 0.4, channels: [0.5])) == WallpaperFrame(time: 3, energy: 0.4, channels: SIMD4(0.5, 0, 0, 0)))
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func folderCoversSkipRenderingAndFPSCeilingsCapPlayback() async throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let covered = registry.templates.filter { registry.assets(for: $0.id).cover(for: $0) != nil }
    let expectedCovers = Set(["aurora-observatory", "gta-vi-countdown", "hinge-garden"] + gameWallpaperIDs)
    #expect(expectedCovers.isSubset(of: Set(covered.map(\.id))))
    let store = WallpaperCoverStore(factory: nil, directory: temporaryDirectory())
    store.request(covered, assets: registry.assets(for:))
    try await settle(timeout: .seconds(5)) { store.images.count == covered.count }
    #expect(store.rendered == 0)
    let suite = "wallpaper-ceiling-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(), displays: FakeDisplay(),
                               surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(), coverDirectory: temporaryDirectory())
    model.start(); model.setBrowsing(true); model.setPreviewVisible(true)
    defer { model.shutdown() }
    #expect(model.previewFPS == 60, "No ceiling declared: playback decides")
    #expect(model.catalog.collection.sections(model.templates).count >= 5 && model.catalog.warnings.isEmpty)
}

// A new scene is a folder with template.json and Scene.metal: no Swift, no shared shader list.
@Test(.requiresGPU, .tags(.gpu)) @MainActor func aTemplateFolderWithItsOwnSceneRegistersAndRendersWithoutSwiftChanges() throws {
    let folder = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try """
    fragment float4 testSceneFragment(WallpaperVertex in [[stage_in]], constant WallpaperUniforms &u [[buffer(0)]]) {
        return float4(u.params[0].x, u.params[0].y, u.energy, 1.0);
    }
    """.write(to: folder.appendingPathComponent("Scene.metal"), atomically: true, encoding: .utf8)
    let scene = WallpaperSceneSource(source: "Scene.metal", fragment: "testSceneFragment", mathMode: "safe",
                                     params: [.init(key: "red", default: 0.25, minimum: 0, maximum: 1), .init(key: "green", default: 0)])
    let catalog = WallpaperShaderCatalog()
    try catalog.register("test-scene", scene: scene, folder: folder)
    #expect(catalog.contains("test-scene") && catalog.parameterKeys["test-scene"] == ["red", "green"])
    #expect(try catalog.scene(for: "test-scene").module.mathMode == .safe)
    let fixtures = try templateV1Fixtures()
    let pulse = try #require(fixtures["pulse"])
    var object = try #require(JSONSerialization.jsonObject(with: pulse) as? [String: Any])
    object["id"] = "test-scene"; object["shader"] = "test-scene"; object["params"] = ["green": 0.5, "red": 3]
    let template = try WallpaperTemplateSchema.decode(try JSONSerialization.data(withJSONObject: object), context: .init(sceneParameters: catalog.parameterKeys)).template
    let pipeline = try WallpaperPipeline(template: template, gpu: try TestGPU.context(), shaders: catalog)
    let pixels = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(time: 0, energy: 1), width: 2, height: 2).pixels
    #expect(pixels[0...3] == [255, 128, 255, 255], "BGRA: energy 1, green 0.5 from params, red clamped to the declared maximum")
    #expect(throws: WallpaperError.missingAsset("Missing.metal")) { try catalog.register("no-file", scene: .init(source: "Missing.metal", fragment: "f"), folder: folder) }
    #expect(throws: WallpaperError.missingAsset("NoSuchModule")) { try catalog.register("no-module", scene: .init(source: "Scene.metal", fragment: "f", dependencies: ["NoSuchModule"]), folder: folder) }
}
