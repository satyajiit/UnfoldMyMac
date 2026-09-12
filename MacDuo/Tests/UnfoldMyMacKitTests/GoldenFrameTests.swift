import AppKit
import Metal
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Pins the exact pixels every pipeline produces at fixed poses, so structural refactors of the
/// rendering stack cannot silently change output. Re-record with `UNFOLDMYMAC_RECORD_GOLDENS=1`
/// only when a shader or math-mode change is intended; the run prints every hash that moved.
@MainActor private enum Golden {
    static let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/golden-frames.json")
    static let width = 320, height = 200

    static func frames() throws -> [String: String] {
        var hashes: [String: String] = [:]
        let poses: [(name: String, context: EffectContext)] = [
            ("open", .init(closure: 0.004, time: 0)),
            ("half", .init(closure: 0.5, time: 1.5)),
            ("sealed", .init(closure: 1, time: 3)),
        ]
        let frost = try FrostPipeline()
        let source = OffscreenHarness.gradient(width: width, height: height)
        let sourceDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        sourceDescriptor.storageMode = .shared; sourceDescriptor.usage = [.shaderRead, .renderTarget]
        let sourceTexture = try #require(frost.gpu.makeTexture(descriptor: sourceDescriptor))
        source.withUnsafeBytes { sourceTexture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        for pose in poses {
            hashes["frost/\(pose.name)"] = try OffscreenHarness.render(device: frost.gpu, queue: frost.queue, pixelFormat: .bgra8Unorm_srgb, width: width, height: height) {
                frost.encode(command: $0, source: sourceTexture, mips: frost.makeMips(source: sourceTexture), pass: $1, context: pose.context)
            }.sha256
        }
        let curtains = try CurtainsPipeline()
        for pose in poses {
            hashes["curtains/\(pose.name)"] = try OffscreenHarness.render(device: curtains.gpu, queue: curtains.queue, pixelFormat: curtains.pixelFormat, width: width, height: height) {
                curtains.encode(command: $0, pass: $1, size: CGSize(width: width, height: height), context: pose.context)
            }.sha256
        }
        let current = try CurrentPipeline()
        for pose in poses {
            hashes["current/\(pose.name)"] = try OffscreenHarness.render(device: current.gpu, queue: current.queue, pixelFormat: current.pixelFormat, width: width, height: height) {
                current.encode(command: $0, pass: $1, size: CGSize(width: width, height: height), context: pose.context)
            }.sha256
        }
        let peekaboo = try PeekabooPipeline()
        for pose in poses {
            hashes["peekaboo/\(pose.name)"] = try OffscreenHarness.render(device: peekaboo.gpu, queue: peekaboo.queue, pixelFormat: peekaboo.pixelFormat, width: width, height: height) {
                peekaboo.encode(command: $0, pass: $1, size: CGSize(width: width, height: height), context: pose.context)
            }.sha256
        }
        for artwork in try LibraryAssets.artworks() {
            let art = try ArtRevealPipeline(artwork: artwork)
            for reveal in ArtRevealMotion.allCases {
                let context = EffectContext(closure: 0.5, parameters: .init(strength: 1, reveal: reveal))
                hashes["art/\(artwork.id.rawValue)/\(reveal.rawValue)"] = try OffscreenHarness.render(device: art.gpu, queue: art.queue, pixelFormat: art.pixelFormat, width: width, height: height) {
                    art.encode(command: $0, pass: $1, size: CGSize(width: width, height: height), context: context)
                }.sha256
            }
        }
        let catalog = try WallpaperShaderCatalog()
        let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
        for template in registry.templates {
            let pipeline = try WallpaperPipeline(template: template, catalog: catalog)
            for (name, time, energy) in [("calm", 2.0, 0.2), ("busy", 5.0, 0.7)] {
                hashes["wallpaper/\(template.id)/\(name)"] = try OffscreenHarness.render(device: catalog.gpu, queue: catalog.queue, pixelFormat: .bgra8Unorm, width: width, height: height) {
                    pipeline.encode(command: $0, pass: $1, size: CGSize(width: width, height: height), time: time, energy: energy, channels: .zero, grid: nil)
                }.sha256
            }
        }
        return hashes
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func renderedFramesMatchTheRecordedGoldens() throws {
    let actual = try Golden.frames()
    if ProcessInfo.processInfo.environment["UNFOLDMYMAC_RECORD_GOLDENS"] == "1" {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: Golden.fixture.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(actual).write(to: Golden.fixture, options: .atomic)
        print("Recorded \(actual.count) golden frame hashes to \(Golden.fixture.path)")
        return
    }
    let expected = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: Golden.fixture))
    let moved = expected.keys.sorted().filter { actual[$0] != expected[$0] }
    let missing = actual.keys.sorted().filter { expected[$0] == nil }
    for key in moved { print("golden moved: \(key)") }
    for key in missing { print("golden missing (new pipeline or pose, re-record): \(key)") }
    #expect(moved.isEmpty, "Rendered output changed for \(moved)")
    #expect(missing.isEmpty, "New frames have no recorded golden: \(missing)")
}
