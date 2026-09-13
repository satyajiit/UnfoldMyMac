import AppKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test func workshopCountsDistinctOrdinaryAppsAndExcludesInfrastructure() {
    let applications: [WorkshopApplication] = [
        .init(bundleID: "com.apple.Safari", bundlePath: "/Safari.app", regular: true),
        .init(bundleID: "com.apple.Safari", bundlePath: "/Safari.app", regular: true),
        .init(bundleID: "com.example.editor", bundlePath: "/Editor.app", regular: true),
        .init(bundleID: "com.apple.finder", bundlePath: "/Finder.app", regular: true),
        .init(bundleID: AppIdentity.bundleIdentifier, bundlePath: "/UnfoldMyMac.app", regular: true),
        .init(bundleID: "com.example.helper", bundlePath: "/Helper.app", regular: false),
        .init(bundleID: "com.example.finished", bundlePath: "/Finished.app", regular: true, terminated: true),
        .init(bundleID: nil, bundlePath: "/Unidentified.app", regular: true),
        .init(bundleID: nil, bundlePath: "/Unidentified.app", regular: true)
    ]
    #expect(WorkshopApplication.count(applications) == 3)
    #expect(WorkshopApplication.count([]) == 0)
}

@Test func workshopAppProviderPublishesOnlyAnAggregate() async throws {
    let date = Date()
    let sample = try await OpenAppsWallpaperProvider(count: { 17 }).sample(at: date).validated(namespace: "apps")
    #expect(sample.numbers == ["apps.count": 17, "apps.available": 1])
    #expect(sample.text.isEmpty && sample.timestamp == date)
}

@Test func workshopFolderCountsShallowEntriesAndPreservesUnavailableState() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("not inspected".utf8).write(to: folder.appendingPathComponent("document.txt"))
    try Data().write(to: folder.appendingPathComponent(".hidden"))
    for name in ["Folder", "Package.app"] {
        let child = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data().write(to: child.appendingPathComponent("nested.txt"))
    }
    try FileManager.default.createSymbolicLink(atPath: folder.appendingPathComponent("Shortcut").path,
                                              withDestinationPath: folder.appendingPathComponent("Folder").path)
    try FileManager.default.createSymbolicLink(atPath: folder.appendingPathComponent("Broken shortcut").path,
                                              withDestinationPath: folder.appendingPathComponent("missing").path)
    let bookmark = try WorkshopFolderAccess.bookmark(for: folder)
    let provider = DesktopItemsWallpaperProvider(bookmark: bookmark)
    let sample = try await provider.sample(at: .now)
    #expect(sample.numbers == ["desktop.items": 5, "desktop.available": 1])
    #expect(sample.text.isEmpty)
    try FileManager.default.removeItem(at: folder)
    await #expect(throws: WallpaperError.self) { try await provider.sample(at: .now) }
}

@Test func workshopEmptyFolderAndDisconnectedFolderAreDifferent() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let provider = DesktopItemsWallpaperProvider(bookmark: try WorkshopFolderAccess.bookmark(for: folder))
    var snapshot = WallpaperSnapshot()
    snapshot.sources["desktop"] = try await provider.sample(at: .now)
    #expect(snapshot.number("desktop.items") == 0 && snapshot.number("desktop.available") == 1)
    snapshot.errors["desktop"] = "Access unavailable"
    #expect(snapshot.number("desktop.items") == nil && snapshot.number("desktop.available") == nil)
}

@Test @MainActor func workshopCatalogConnectsAppsAutomaticallyAndFolderOnlyAfterSelection() throws {
    let catalog = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == "the-workshop" })
    #expect(template.contentCollection == .scenes)
    #expect(Set(template.contentCapabilities) == [.lid, .openApps, .localFiles])
    #expect(WallpaperSetupController.isReady(template, connections: [:]))
    #expect(WallpaperProviderAssembly.providers(for: template, connections: [:]).map(\.id) == ["apps"])
    let settings = WallpaperConnectionSettings(enabled: true, path: "/not-consented")
    #expect(WallpaperProviderAssembly.providers(for: template, connections: ["desktop-folder": settings]).map(\.id) == ["apps"])
    let selected = WallpaperConnectionSettings(enabled: true, folderBookmark: Data([1, 2, 3]))
    #expect(Set(WallpaperProviderAssembly.providers(for: template, connections: ["desktop-folder": selected]).map(\.id)) == ["apps", "desktop"])
}

@Test @MainActor func workshopDoesNotStartGardenMotionAndPreferencesReachTheFrame() {
    let motion = GardenTestMotion()
    let inputs = WallpaperInputService(audio: GardenTestAudio(), makeSensor: { GardenTestLid() }, makeMotion: { motion })
    let consumer = UUID()
    inputs.configure(connections: ["the-workshop": ["workshop": .init(liveCounts: false, mirrored: true)]], suspended: false, reducedMotion: false)
    inputs.setConsumer(consumer, template: "the-workshop", visible: true, animated: true)
    #expect(inputs.isSampling && !motion.running && motion.starts == 0)
    #expect(!inputs.showsWorkshopCounts && inputs.inputs(for: "the-workshop").mirrored)
    inputs.setConnections([:])
    #expect(inputs.showsWorkshopCounts && !inputs.inputs(for: "the-workshop").mirrored)
    inputs.removeConsumer(consumer)
    #expect(!inputs.isSampling)
}

@Test func workshopLargeFolderKeepsExactCountsAndHonorsCancellation() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    for index in 0..<2_000 { try Data().write(to: folder.appendingPathComponent("item-\(index)")) }
    let settings = WallpaperConnectionSettings(enabled: true, folderBookmark: try WorkshopFolderAccess.bookmark(for: folder))
    let saved = try JSONDecoder().decode(WallpaperConnectionSettings.self, from: JSONEncoder().encode(settings))
    let provider = DesktopItemsWallpaperProvider(bookmark: try #require(saved.folderBookmark))
    let sample = try await provider.sample(at: .now)
    #expect(sample.numbers["desktop.items"] == 2_000)
    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await provider.sample(at: .now)
    }
    await #expect(throws: CancellationError.self) { try await cancelled.value }
}

@Test @MainActor func workshopCustomizationPreviewsCancelsAndPersists() throws {
    let suite = "workshop-setup-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = UserDefaultsPreferencesStore(defaults: defaults)
    let inputs = WallpaperInputService(audio: GardenTestAudio(), makeSensor: { GardenTestLid() })
    let setup = WallpaperSetupController(preferences: preferences, inputs: inputs)
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == "the-workshop" })
    let edited = WallpaperConnectionSettings(parallax: false, oneLiners: false, liveCounts: false, mirrored: true)
    setup.open(template); setup.setDraft(edited, for: "workshop")
    #expect(!inputs.showsWorkshopCounts && inputs.inputs(for: template.id).mirrored)
    #expect(inputs.workshopQuote == nil)
    setup.cancel()
    #expect(inputs.showsWorkshopCounts && !inputs.inputs(for: template.id).mirrored)
    #expect(inputs.workshopQuote?.text == WorkshopQuoteDeck.lines.first)
    #expect(setup.configuration("workshop", for: template.id) != edited)
    setup.open(template); setup.setDraft(edited, for: "workshop"); setup.finish()
    let reloaded = WallpaperSetupController(preferences: preferences)
    #expect(reloaded.configuration("workshop", for: template.id) == edited)

    guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WORKSHOP_ARTIFACTS"] else { return }
    let output = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    inputs.setConnections([:])
    if let background = NSImage(contentsOf: output.appendingPathComponent("day.png")) {
        var snapshot = WallpaperSnapshot()
        snapshot.sources["apps"] = .init(timestamp: .now, numbers: ["apps.count": 7])
        snapshot.sources["desktop"] = .init(timestamp: .now, numbers: ["desktop.items": 23])
        let renderer = ImageRenderer(content: WallpaperSceneOverlay(template: template, snapshot: snapshot, inputs: inputs)
            .frame(width: 960, height: 600).background(Image(nsImage: background).resizable()))
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("with-caption.png"))
    }
}

@Test func workshopMotivationRotatesOnlyWhileAnimatingAndChangesAtTheFade() {
    var cycle = GardenQuoteCycle(lines: WorkshopQuoteDeck.lines)
    var previous = cycle.advance(delta: 0, next: false, animated: true, interval: 45)
    var seen = Set([previous.text])
    var changesAreHidden = true
    for _ in 0..<3_800 {
        let value = cycle.advance(delta: 0.1, next: false, animated: true, interval: 45)
        if value.text != previous.text { changesAreHidden = changesAreHidden && value.opacity < 0.02 }
        seen.insert(value.text); previous = value
    }
    #expect(seen == Set(WorkshopQuoteDeck.lines) && changesAreHidden)
    let paused = cycle.advance(delta: 60, next: true, animated: false, interval: 45)
    #expect(paused.text == previous.text && paused.opacity == 1)
    cycle.pause()
    #expect(cycle.advance(delta: 0.1, next: false, animated: true, interval: 45).text == paused.text)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func workshopReferenceFrames() throws {
    let catalog = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == "the-workshop" }, "\(registry.errors)")
    let pipeline = try WallpaperPipeline(template: template, gpu: TestGPU.context(), shaders: catalog)
    var light = WallpaperLiveInputs(); light.daylight = 0.85
    var night = light; night.daylight = 0
    var closed = light; closed.lidOpen = 0
    var half = light; half.lidOpen = 0.5
    var still = light; still.reducedMotion = true
    var mirrored = light; mirrored.mirrored = true
    var charging = light; charging.externalPower = 1; charging.charging = 1.8
    let normal = SIMD4<Float>(7.0 / 12, 23.0 / 24, 1, 1)
    let poses: [(String, WallpaperLiveInputs, SIMD4<Float>)] = [
        ("day", light, normal), ("night", night, normal), ("closed", closed, normal), ("half-open", half, normal),
        ("quiet", light, SIMD4(0, 0, 1, 1)), ("crowded", light, SIMD4(1, 1, 1, 1)),
        ("disconnected", light, SIMD4(7.0 / 12, 0, 0, 1)), ("mirrored", mirrored, normal),
        ("charging", charging, normal), ("still", still, normal)
    ]
    let output = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WORKSHOP_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
    if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
    var hashes = Set<String>()
    for (name, live, channels) in poses {
        let frame = try OffscreenRenderer.render(pipeline, frame: .init(time: 18, channels: channels, liveInputs: live),
                                                width: output == nil ? 640 : 1920, height: output == nil ? 400 : 1200)
        hashes.insert(frame.sha256)
        #expect(stride(from: 3, to: frame.pixels.count, by: 4).allSatisfy { frame.pixels[$0] == 255 })
        print(String(format: "WORKSHOP %@ %d×%d GPU %.2f ms", name, frame.width, frame.height, frame.gpuSeconds * 1000))
        if let output {
            let image = NSBitmapImageRep(cgImage: try OffscreenRenderer.cgImage(frame))
            try #require(image.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
        }
    }
    // The composed still intentionally matches the ordinary frame at the same frozen time.
    #expect(hashes.count == poses.count - 1)
    let frozenA = try OffscreenRenderer.render(pipeline, frame: .init(time: 1, channels: normal, liveInputs: still), width: 640, height: 400)
    let frozenB = try OffscreenRenderer.render(pipeline, frame: .init(time: 999, channels: normal, liveInputs: still), width: 640, height: 400)
    #expect(frozenA.sha256 == frozenB.sha256)
    if let output {
        for (name, width, height) in [("native", 3024, 1964), ("ultrawide", 3440, 1440), ("portrait", 1440, 2560), ("cover", 1280, 800)] {
            let frame = try OffscreenRenderer.render(pipeline, frame: .init(time: 18, channels: normal, liveInputs: light), width: width, height: height)
            let image = NSBitmapImageRep(cgImage: try OffscreenRenderer.cgImage(frame))
            try #require(image.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
        }
    }
}
