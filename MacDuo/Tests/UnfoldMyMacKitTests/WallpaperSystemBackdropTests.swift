import AppKit
import Testing
@testable import UnfoldMyMacKit

@MainActor private final class FakeDesktopImages: WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] = [.init(id: "display", size: CGSize(width: 800, height: 520))]
    var images = ["display": WallpaperDesktopImage(url: URL(fileURLWithPath: "/original.heic"),
        options: [.imageScaling: 3, .allowClipping: false, .fillColor: NSColor.red])]
    var writes = 0
    var failAfterSetting = false
    var delayUpdates = false
    var pending: [WallpaperDesktopImage] = []
    func current(on screen: String) -> WallpaperDesktopImage? { images[screen] }
    func set(_ image: WallpaperDesktopImage, on screen: String) throws {
        writes += 1
        if delayUpdates { pending.append(image); return }
        images[screen] = image
        if failAfterSetting { throw CocoaError(.fileWriteUnknown) }
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func systemBackdropPersistsOriginalAcrossTemplateChangesAndRestart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = FakeDesktopImages(), original = access.images["display"]
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let templates = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates
    let first = try WallpaperPipeline(template: templates[0], gpu: gpu, shaders: catalog)
    let backdrop = WallpaperSystemBackdrop(access: access, directory: root)
    try backdrop.apply(first)
    let installed = try #require(access.images["display"])
    #expect(installed.url != original?.url)
    #expect(NSImage(contentsOf: installed.url)?.size == CGSize(width: 800, height: 520))
    try backdrop.apply(first)
    #expect(access.writes == 1)
    try backdrop.apply(WallpaperPipeline(template: templates[1], gpu: gpu, shaders: catalog))
    #expect(access.writes == 2)
    let restarted = WallpaperSystemBackdrop(access: access, directory: root)
    try restarted.restore()
    #expect(access.images["display"] == original)
    // A different Space still pointing to the old companion can be restored later.
    access.images["display"] = installed
    try restarted.restore()
    #expect(access.images["display"] == original)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func systemBackdropPreservesLaterUserChoicesAndRestoresReconnectedDisplays() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = FakeDesktopImages(), original = access.images["display"]
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let template = try #require(WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates.first)
    let backdrop = WallpaperSystemBackdrop(access: access, directory: root)
    try backdrop.apply(WallpaperPipeline(template: template, gpu: gpu, shaders: catalog))
    let installed = access.images["display"]
    let chosen = WallpaperDesktopImage(url: URL(fileURLWithPath: "/chosen-later.png"))
    access.images["display"] = chosen
    try backdrop.restore()
    #expect(access.images["display"] == chosen)
    access.images["display"] = installed; access.screens = []
    try backdrop.restore()
    #expect(access.images["display"] == installed)
    access.screens = [.init(id: "display", size: CGSize(width: 800, height: 520))]
    try backdrop.restore()
    #expect(access.images["display"] == original)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func systemBackdropJournalsBeforeMutationAndRejectsCorruptRecovery() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = FakeDesktopImages(), original = access.images["display"]
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let template = try #require(WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates.first)
    let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
    access.failAfterSetting = true
    #expect(throws: (any Error).self) { try WallpaperSystemBackdrop(access: access, directory: root).apply(pipeline) }
    access.failAfterSetting = false
    try WallpaperSystemBackdrop(access: access, directory: root).restore()
    #expect(access.images["display"] == original)
    access.delayUpdates = true
    let immediateStop = WallpaperSystemBackdrop(access: access, directory: root)
    try immediateStop.apply(pipeline)
    try immediateStop.restore()
    #expect(access.pending.count == 2)
    #expect(access.pending.last == original)
    access.delayUpdates = false
    try Data("invalid".utf8).write(to: root.appendingPathComponent("restoration.json"))
    let writes = access.writes
    #expect(throws: (any Error).self) { try WallpaperSystemBackdrop(access: access, directory: root).apply(pipeline) }
    #expect(access.writes == writes)
}

/// Explicit device check only; the ordinary suite never changes desktop preferences.
@Test(.requiresGPU, .tags(.gpu)) @MainActor func nativeSystemBackdropAndCodexMetadataIntegration() async throws {
    guard ProcessInfo.processInfo.environment["UNFOLDMYMAC_NATIVE_BACKDROP_TEST"] == "1" else { return }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("UnfoldBackdropCheck-" + UUID().uuidString)
    let access = SystemWallpaperDesktopImages()
    let original = access.screens.compactMap { screen in access.current(on: screen.id).map { (screen.id, $0) } }
    let backdrop = WallpaperSystemBackdrop(access: access, directory: root)
    defer { try? backdrop.restore() }
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let template = try #require(WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates.first { $0.id == "codex-foundry" })
    try backdrop.apply(WallpaperPipeline(template: template, gpu: gpu, shaders: catalog))
    // The system's preference change propagates asynchronously through WallpaperAgent.
    for _ in 0..<40 {
        if access.screens.allSatisfy({ access.current(on: $0.id)?.url.deletingLastPathComponent().path == root.path }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    for screen in access.screens {
        try #require(access.current(on: screen.id)?.url.deletingLastPathComponent().path == root.path)
    }
    try backdrop.restore()
    for _ in 0..<40 {
        if original.allSatisfy({ access.current(on: $0.0)?.url == $0.1.url }) { break }
        try await Task.sleep(for: .milliseconds(50))
    }
    for (screen, image) in original { try #require(access.current(on: screen)?.url == image.url) }
    // Immediate Apply → Stop must also restore while the set is still propagating.
    try backdrop.apply(WallpaperPipeline(template: template, gpu: gpu, shaders: catalog))
    try backdrop.restore()
    try await Task.sleep(for: .milliseconds(500))
    for (screen, image) in original { try #require(access.current(on: screen)?.url == image.url) }
    let metadata = try await CodexWallpaperProvider().sample(at: .now)
    try #require((metadata.numbers["codex.sessions"] ?? 0) > 0)
    try #require((metadata.numbers["codex.tokens"] ?? 0) > 0)
    print("Native wallpaper apply/restore and nonzero local Codex metadata verified.")
}

// W4: the backdrop remembers what it installed by identity, never by holding the pipeline.
@Test(.requiresGPU, .tags(.gpu)) @MainActor func systemBackdropDoesNotRetainPipelines() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let access = FakeDesktopImages()
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let template = try #require(WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates.first)
    let backdrop = WallpaperSystemBackdrop(access: access, directory: root)
    weak var released: WallpaperPipeline?
    try {
        let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
        released = pipeline
        try backdrop.apply(pipeline)
    }()
    #expect(released == nil)
    try backdrop.apply(WallpaperPipeline(template: template, gpu: gpu, shaders: catalog))
    #expect(access.writes == 1, "An equivalent pipeline for the same template is recognised without re-rendering")
}
