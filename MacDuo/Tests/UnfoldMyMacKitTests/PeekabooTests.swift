import AppKit
import Metal
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor private struct PeekabooHarness {
    let pipeline: PeekabooPipeline
    init() throws { pipeline = try PeekabooPipeline(gpu: try TestGPU.context()) }
    func render(_ context: EffectContext, width: Int = 640, height: Int = 420) throws -> (pixels: [UInt8], gpuTime: Double) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pipeline.surface.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .renderTarget
        let texture = try #require(pipeline.gpu.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, pass: pass, size: CGSize(width: width, height: height), context: context))
        command.commit(); command.waitUntilCompleted(); #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return (pixels, command.gpuEndTime - command.gpuStartTime)
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func peekabooHasImmediateEntryClearOpeningAndSealedCompletion() throws {
    let harness = try PeekabooHarness()
    let onset = EffectMath.liveProgress(lid: 108, activation: 108, completionFraction: 0.8)
    for strength in [0.0, 1.0] {
        for time in [0.0, 3.45, 100.0] {
            #expect(try harness.render(.init(closure: 0, parameters: .init(strength: strength), time: time)).pixels.allSatisfy { $0 == 0 })
            let start = try harness.render(.init(closure: onset, parameters: .init(strength: strength), time: time)).pixels
            for x in [0, 639] { #expect(start[(210 * 640 + x) * 4 + 3] == 255) }
            #expect(start[(210 * 640 + 320) * 4 + 3] == 0)
        }
        for (width, height) in [(640, 420), (300, 500), (1000, 300)] {
            let half = try harness.render(.init(closure: 0.5, parameters: .init(strength: strength)), width: width, height: height).pixels
            for y in 0..<height { #expect(half[(y * width + width / 2) * 4 + 3] == 0) }
            #expect(stride(from: 0, to: half.count, by: 4).allSatisfy { i in (0..<3).allSatisfy { half[i + $0] <= half[i + 3] } })
            let closed = try harness.render(.init(closure: EffectMath.calibratedClosure(0.8, completionFraction: 0.8), parameters: .init(strength: strength), time: 3.45), width: width, height: height).pixels
            #expect(stride(from: 3, to: closed.count, by: 4).allSatisfy { closed[$0] == 255 })
            // Resize/reversal must clear both color and depth from the closed pose.
            #expect(try harness.render(.init(closure: 0.5, parameters: .init(strength: strength)), width: width, height: height).pixels == half)
            #expect(try harness.render(.init(closure: 0), width: width, height: height).pixels.allSatisfy { $0 == 0 })
        }
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func peekabooMovesBlinksAndHonorsPauseAndReducedMotion() throws {
    let harness = try PeekabooHarness()
    let pose = try harness.render(.init(closure: 0.72, time: 0)).pixels
    #expect(try harness.render(.init(closure: 0.72, time: 0)).pixels == pose)
    #expect(try harness.render(.init(closure: 0.72, time: 1)).pixels != pose)
    #expect(try harness.render(.init(closure: 0.72, time: 3.45)).pixels != pose)
    #expect(try harness.render(.init(closure: 0.72, time: 100, reduceMotion: true)).pixels == pose)
    let calm = try harness.render(.init(closure: 0.72, parameters: .init(strength: 0))).pixels
    #expect(try harness.render(.init(closure: 0.72, parameters: .init(strength: 0), time: 100)).pixels == calm)
    let id = EffectID(rawValue: "peekaboo")
    let entry = try #require(EffectRegistry.builtIn().entry(for: id))
    #expect(entry.descriptor.id == id && entry.descriptor.category == .motion)
    #expect(entry.descriptor.hasContinuousMotion && !entry.descriptor.requiresCapture)
    let renderer = try entry.makeRenderer(try TestGPU.context())
    #expect(renderer.animatesWithTime && !(renderer is any DesktopFrameSink)); renderer.stop()
    if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_PEEKABOO_ARTIFACTS"] {
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, closure, time) in [("open", 0.72, 0.0), ("blink", 0.72, 3.45), ("closed", 1.0, 0.0)] {
            let pixels = try harness.render(.init(closure: closure, time: time), width: 1440, height: 960).pixels
            let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
            let image = try #require(CGImage(width: 1440, height: 960, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1440 * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent("peekaboo-\(name).png"))
        }
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func peekabooNativeResolutionFrameBudget() throws {
    let harness = try PeekabooHarness()
    var times: [Double] = []
    for frame in 0..<8 {
        let result = try harness.render(.init(closure: 1, time: Double(frame) / 60), width: 3024, height: 1964)
        if frame > 1 { times.append(result.gpuTime) }
    }
    let median = times.sorted()[times.count / 2]
    print(String(format: "Peekaboo 3024×1964 GPU median: %.2f ms", median * 1000))
    #expect(median < 1.0 / 60)
}
