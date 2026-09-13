import AppKit
import ImageIO
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

let gameWallpaperIDs = [
    "wolverine-after-rain", "cyberpunk-night-city", "elden-ring-grace", "doom-ember-citadel",
    "forza-horizon-dusk", "hollow-knight-greenpath", "wukong-cloud-temple", "red-dead-sunset",
    "baldurs-gate-astral", "ghost-tsushima-maple",
]

@Test(.requiresGPU, .tags(.gpu), arguments: gameWallpaperIDs)
@MainActor func gameWallpaperRendersArtworkLogoMotionAndLidInput(_ id: String) throws {
    let shaders = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: shaders, loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == id })
    let assets = registry.assets(for: id)
    let artworkName = try #require(template.image)
    let artworkURL = try #require(assets.image(artworkName))
    let artworkSource = try #require(CGImageSourceCreateWithURL(artworkURL as CFURL, nil))
    let artworkProperties = try #require(CGImageSourceCopyPropertiesAtIndex(artworkSource, 0, nil) as? [CFString: Any])
    #expect((artworkProperties[kCGImagePropertyPixelWidth] as? Int) == 3840)
    #expect((artworkProperties[kCGImagePropertyPixelHeight] as? Int) == 2402)
    #expect(assets.mark(try #require(template.emblem).asset) != nil)
    #expect(assets.image("Official") != nil)
    #expect(template.metadata?.collection == "wallpapers")
    let pipeline = try WallpaperPipeline(template: template, gpu: try TestGPU.context(), shaders: shaders, assets: assets)
    #expect(pipeline.surface.maximumDimension == nil)
    func render(_ frame: WallpaperFrame, width: Int = 640, height: Int = 400) throws -> OffscreenFrame {
        try OffscreenRenderer.render(pipeline, frame: frame, width: width, height: height)
    }
    let pose = WallpaperFrame(time: 4, energy: 0.3)
    let first = try render(pose)
    #expect(try render(pose).pixels == first.pixels)
    #expect(try render(.init(time: 9, energy: 0.3)).pixels != first.pixels)
    #expect(try render(.init(time: 4, energy: 0.9)).pixels != first.pixels)
    var closed = WallpaperLiveInputs(); closed.lidOpen = 0
    #expect(try render(.init(time: 4, energy: 0.3, liveInputs: closed)).pixels != first.pixels)
    var moved = WallpaperLiveInputs(); moved.parallax = SIMD2(0.8, -0.5)
    #expect(try render(.init(time: 4, energy: 0.3, liveInputs: moved)).pixels != first.pixels)
    var quiet = WallpaperLiveInputs(); quiet.reducedMotion = true
    // Real data must change the scene even with a fixed clock and reduced motion.
    let lowData = WallpaperFrame(time: 4, energy: 0.3, channels: SIMD4(0.1, 0.25, 1, 1), liveInputs: quiet)
    let highData = WallpaperFrame(time: 4, energy: 0.3, channels: SIMD4(0.9, 0.25, 1, 1), liveInputs: quiet)
    #expect(try render(lowData).pixels != render(highData).pixels)
    if id == "ghost-tsushima-maple" {
        let north = WallpaperFrame(time: 4, energy: 0.3, channels: SIMD4(0.5, 0, 1, 0))
        let south = WallpaperFrame(time: 4, energy: 0.3, channels: SIMD4(0.5, 0.5, 1, 0))
        #expect(try render(north).pixels != render(south).pixels)
    }
    let still = WallpaperFrame(time: template.stillPose.time, energy: 0.25, liveInputs: quiet)
    var stillMoved = still; stillMoved.liveInputs.parallax = SIMD2(0.9, 0.8)
    #expect(try render(still).pixels == render(stillMoved).pixels)
    for (width, height) in [(640, 400), (300, 500), (1000, 300)] {
        let resized = try render(pose, width: width, height: height)
        #expect(stride(from: 3, to: resized.pixels.count, by: 4).allSatisfy { resized.pixels[$0] == 255 })
    }
    var samples: [Double] = []
    for i in 0..<5 {
        let frame = try render(.init(time: Double(i), energy: 0.5), width: 3840, height: 2400)
        if i > 0 { samples.append(frame.gpuSeconds) }
    }
    let median = samples.sorted()[samples.count / 2]
    print("\(id) 3840×2400 GPU median: \(median * 1000) ms")
    #expect(median < 1.0 / 30)
    if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_GAME_ARTIFACTS"] {
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cover = try render(WallpaperFrame(pose: template.coverPose), width: 1440, height: 900)
        let image = try OffscreenRenderer.cgImage(cover)
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent("\(id).png"))
    }
}
