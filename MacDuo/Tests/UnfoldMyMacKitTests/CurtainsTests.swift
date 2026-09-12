import AppKit
import Metal
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor private struct OffscreenCurtains {
    let pipeline: CurtainsPipeline
    init() throws { pipeline = try CurtainsPipeline(gpu: try TestGPU.context()) }

    func render(_ closure: Double, strength: Double = 1, width: Int = 640, height: Int = 420) throws -> (bytes: [UInt8], milliseconds: Double) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget]
        let texture = try #require(pipeline.gpu.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, pass: pass, size: CGSize(width: width, height: height),
                               context: .init(closure: closure, parameters: .init(strength: strength))))
        command.commit(); command.waitUntilCompleted()
        #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return (pixels, max(0, command.gpuEndTime - command.gpuStartTime) * 1000)
    }

    func save(_ pixels: [UInt8], width: Int, height: Int, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["UNFOLDMYMAC_CURTAIN_ARTIFACTS"] ?? ProcessInfo.processInfo.environment["LUMA_CURTAIN_ARTIFACTS"] else { return }
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

@Test @MainActor func curtainsOpenCloseAndReverseWithoutLeakingTheDesktop() throws {
    let renderer = try OffscreenCurtains()
    let open = try renderer.render(0).bytes
    #expect(open.allSatisfy { $0 == 0 })
    let half = try renderer.render(0.5).bytes
    // Opaque velvet at either side, untouched desktop in the opening.
    for y in [0, 100, 210, 419] {
        #expect(half[(y * 640 + 40) * 4 + 3] == 255)
        #expect(half[(y * 640 + 600) * 4 + 3] == 255)
        #expect(half[(y * 640 + 320) * 4 + 3] == 0)
    }
    let closed = try renderer.render(1).bytes
    #expect(stride(from: 3, to: closed.count, by: 4).allSatisfy { closed[$0] == 255 })
    // Sculpted lighting remains visible after the centre seam closes.
    let reds = (0..<640).map { closed[(210 * 640 + $0) * 4 + 2] }
    #expect(Int(reds.max()!) - Int(reds.min()!) > 45)
    #expect(reds.max()! > 100)
    #expect(try renderer.render(0.5).bytes == half)
    #expect(try renderer.render(0).bytes == open)
    let calibrated = EffectMath.calibratedClosure(0.8, completionFraction: 0.8)
    #expect(try renderer.render(calibrated).bytes == closed)

    for (name, progress) in [("curtains-partial.png", 0.5), ("curtains-closed.png", 1.0)] {
        let frame = try renderer.render(progress, width: 1440, height: 960)
        try renderer.save(frame.bytes, width: 1440, height: 960, name: name)
    }
}

@Test @MainActor func curtainsFoldDepthAndResizePreserveCoverage() throws {
    let renderer = try OffscreenCurtains()
    let shallow = try renderer.render(1, strength: 0, width: 400, height: 600).bytes
    let deep = try renderer.render(1, width: 400, height: 600).bytes
    #expect(shallow != deep)
    for pixels in [shallow, deep] {
        #expect(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 })
    }
    var timings: [Double] = []
    for index in 0..<12 {
        let frame = try renderer.render(Double(index + 1) / 12, width: 3024, height: 1964)
        if index >= 2 { timings.append(frame.milliseconds) }
    }
    let median = timings.sorted()[timings.count / 2]
    print("Curtains 3024×1964 GPU median: \(String(format: "%.2f", median)) ms (60 Hz budget 16.67 ms)")
}

@Test @MainActor func curtainsEnterOnTheFirstLiveFrame() throws {
    let renderer = try OffscreenCurtains()
    let onset = EffectMath.liveProgress(lid: 108, activation: 108, completionFraction: 0.8)
    for strength in [0.0, 1.0] {
        let pixels = try renderer.render(onset, strength: strength).bytes
        for y in [20, 210, 400] {
            #expect(pixels[(y * 640) * 4 + 3] == 255)
            #expect(pixels[(y * 640 + 639) * 4 + 3] == 255)
            #expect(pixels[(y * 640 + 320) * 4 + 3] == 0)
        }
    }
}

@Test @MainActor func curtainsRegistrationAndPersistence() throws {
    let registry = EffectRegistry.builtIn()
    let entry = registry.entry(for: .curtains)
    #expect(entry.descriptor.id == .curtains)
    #expect(!entry.descriptor.requiresCapture)
    #expect(entry.descriptor.parameterTitle == "Fold depth")
    let renderer = try entry.makeRenderer(try TestGPU.context())
    #expect(renderer.ready)
    #expect(!(renderer is any DesktopFrameSink))
    renderer.stop()
    var settings = UnfoldMyMacSettings()
    settings.effect = .curtains
    settings.parameters[EffectID.curtains.rawValue] = .init(strength: 0.6)
    let decoded = try JSONDecoder().decode(UnfoldMyMacSettings.self, from: JSONEncoder().encode(settings))
    #expect(decoded.effect == .curtains)
    #expect(decoded.parameters(for: .curtains).strength == 0.6)
}
