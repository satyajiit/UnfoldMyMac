import AppKit
import Metal
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor private struct OffscreenArt {
    let pipeline: ArtRevealPipeline
    init(_ artwork: ArtworkDefinition) throws { pipeline = try ArtRevealPipeline(artwork: artwork, gpu: try TestGPU.context()) }

    func render(_ closure: Double, strength: Double = 1, reveal: ArtRevealMotion? = nil, width: Int = 768, height: Int = 512) throws -> [UInt8] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget]
        let texture = try #require(pipeline.gpu.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, pass: pass, size: CGSize(width: width, height: height),
                               context: .init(closure: closure, parameters: .init(strength: strength, reveal: reveal))))
        command.commit(); command.waitUntilCompleted()
        #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return pixels
    }

    func save(_ pixels: [UInt8], width: Int, height: Int, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["UNFOLDMYMAC_ART_ARTIFACTS"] ?? ProcessInfo.processInfo.environment["LUMA_ART_ARTIFACTS"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                         bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: url.appendingPathComponent(name))
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func artRevealsAreTransparentReversibleAndPremultiplied() throws {
    for artwork in try EffectAssets.artworks() {
        let renderer = try OffscreenArt(artwork)
        let open = try renderer.render(0)
        #expect(open.allSatisfy { $0 == 0 })
        let half = try renderer.render(0.5)
        #expect(half[(256 * 768 + 384) * 4 + 3] == 0)
        #expect(half[(256 * 768 + 38) * 4 + 3] == 255)
        #expect(half[(256 * 768 + 730) * 4 + 3] == 255)
        #expect(stride(from: 0, to: half.count, by: 4).allSatisfy { index in
            (0..<3).allSatisfy { Int(half[index + $0]) <= Int(half[index + 3]) + 1 }
        })
        let closed = try renderer.render(1)
        #expect(stride(from: 3, to: closed.count, by: 4).allSatisfy { closed[$0] == 255 })
        #expect(try renderer.render(0.5) == half)
        #expect(try renderer.render(0) == open)
        #expect(try renderer.render(EffectMath.calibratedClosure(0.8, completionFraction: 0.8)) == closed)
        #expect(try renderer.render(0.5, strength: 0) != half)
        // Full coverage does not depend on the original artwork's aspect ratio.
        let portrait = try renderer.render(1, width: 300, height: 500)
        #expect(stride(from: 3, to: portrait.count, by: 4).allSatisfy { portrait[$0] == 255 })
        if (ProcessInfo.processInfo.environment["UNFOLDMYMAC_ART_ARTIFACTS"] ?? ProcessInfo.processInfo.environment["LUMA_ART_ARTIFACTS"]) != nil {
            let sample = try renderer.render(0.72, width: 1440, height: 960)
            try renderer.save(sample, width: 1440, height: 960, name: "\(artwork.id.rawValue)-separated.png")
        }
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func assembledArtworkPreservesOrientationAndSRGBColour() throws {
    for artwork in try EffectAssets.artworks() {
        let renderer = try OffscreenArt(artwork)
        let source = renderer.pipeline.artwork
        #expect(source.pixelFormat == .rgba8Unorm_srgb || source.pixelFormat == .bgra8Unorm_srgb)
        var original = [UInt8](repeating: 0, count: source.width * source.height * 4)
        original.withUnsafeMutableBytes { source.getBytes($0.baseAddress!, bytesPerRow: source.width * 4,
            from: MTLRegionMake2D(0, 0, source.width, source.height), mipmapLevel: 0) }
        let assembled = try renderer.render(1, width: source.width, height: source.height)
        var maximumDifference = 0
        for y in stride(from: 0, to: source.height, by: 19) {
            for x in stride(from: 0, to: source.width, by: 19) {
                let index = (y * source.width + x) * 4
                for component in 0..<3 {
                    let originalComponent = source.pixelFormat == .rgba8Unorm_srgb ? 2 - component : component
                    maximumDifference = max(maximumDifference, abs(Int(assembled[index + component]) - Int(original[index + originalComponent])))
                }
            }
        }
        #expect(maximumDifference <= 2)
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func artworkEntersOnTheFirstLiveFrame() throws {
    let onset = EffectMath.liveProgress(lid: 108, activation: 108, completionFraction: 0.8)
    for artwork in try EffectAssets.artworks() {
        let renderer = try OffscreenArt(artwork)
        for strength in [0.0, 1.0] {
            let pixels = try renderer.render(onset, strength: strength)
            for edgeX in [0, 767] {
                // Require actual opaque artwork on both sides, not just a drop shadow.
                #expect((0..<512).contains { pixels[($0 * 768 + edgeX) * 4 + 3] > 200 })
            }
            #expect(pixels[(256 * 768 + 384) * 4 + 3] == 0)
        }
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func artStylesPersistWithoutCaptureCapability() throws {
    let registry = EffectRegistry.builtIn()
    for artwork in try EffectAssets.artworks() {
        let entry = try #require(registry.entry(for: artwork.id))
        #expect(entry.descriptor.id == artwork.id)
        #expect(!entry.descriptor.requiresCapture)
        let renderer = try entry.makeRenderer(try TestGPU.context())
        #expect(!(renderer is any DesktopFrameSink))
        renderer.stop()
        var settings = UnfoldMyMacSettings()
        settings.effect = artwork.id
        settings.parameters[artwork.id.rawValue] = .init(strength: 0.7)
        let decoded = try JSONDecoder().decode(UnfoldMyMacSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.effect == artwork.id)
        #expect(decoded.parameters(for: artwork.id).strength == 0.7)
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func anyArtworkCanUseAnyRevealWithoutChangingItsIdentity() throws {
    let artwork = try #require(EffectAssets.artworks().first)
    let renderer = try OffscreenArt(artwork)
    let closed = try renderer.render(1)
    for reveal in ArtRevealMotion.allCases {
        #expect(try renderer.render(0, reveal: reveal).allSatisfy { $0 == 0 })
        #expect(try renderer.render(1, reveal: reveal) == closed)
        let half = try renderer.render(0.5, reveal: reveal)
        #expect(half[(256 * 768 + 384) * 4 + 3] == 0)
        #expect(try renderer.render(0.5, reveal: reveal) == half)
        let onset = try renderer.render(0.004, reveal: reveal)
        for x in [0, 767] { #expect((0..<512).contains { onset[($0 * 768 + x) * 4 + 3] > 200 }) }
    }
}
