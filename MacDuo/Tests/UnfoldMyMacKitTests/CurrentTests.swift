import AppKit
import Metal
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor private struct CurrentHarness {
    let pipeline: CurrentPipeline
    init() throws { pipeline = try CurrentPipeline(gpu: try TestGPU.context()) }
    func render(_ context: EffectContext, width: Int = 640, height: Int = 420) throws -> (pixels: [UInt8], gpuTime: Double) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget]
        let texture = try #require(pipeline.gpu.device.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, pass: pass, size: CGSize(width: width, height: height), context: context))
        command.commit(); command.waitUntilCompleted(); #expect(command.error == nil)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return (pixels, command.gpuEndTime - command.gpuStartTime)
    }
}

@Test @MainActor func currentFlowsButRespectsClearCoveragePauseAndReducedMotion() throws {
    let harness = try CurrentHarness()
    #expect(try harness.render(.init(closure: 0, time: 10)).pixels.allSatisfy { $0 == 0 })
    let onset = try harness.render(.init(closure: 0.004)).pixels
    #expect(onset[(210 * 640) * 4 + 3] > 200)
    #expect(onset[(210 * 640 + 639) * 4 + 3] > 200)
    let half = try harness.render(.init(closure: 0.5, time: 1)).pixels
    #expect(half[(210 * 640 + 320) * 4 + 3] == 0)
    #expect(half[(210 * 640 + 16) * 4 + 3] == 255)
    #expect(try harness.render(.init(closure: 0.5, time: 1)).pixels == half)
    #expect(try harness.render(.init(closure: 0.5, time: 2)).pixels != half)
    #expect(try harness.render(.init(closure: 0.5, parameters: .init(strength: 0), time: 1)).pixels != half)
    let quiet = try harness.render(.init(closure: 0.5, time: 1, reduceMotion: true)).pixels
    #expect(try harness.render(.init(closure: 0.5, time: 100, reduceMotion: true)).pixels == quiet)
    #expect(stride(from: 0, to: half.count, by: 4).allSatisfy { i in (0..<3).allSatisfy { half[i+$0] <= half[i+3] } })
    for (width, height) in [(640, 420), (300, 500)] {
        let closed = try harness.render(.init(closure: EffectMath.calibratedClosure(0.8, completionFraction: 0.8)), width: width, height: height).pixels
        #expect(stride(from: 3, to: closed.count, by: 4).allSatisfy { closed[$0] == 255 })
    }
    let entry = try #require(EffectRegistry.builtIn().entry(for: .current))
    #expect(entry.descriptor.hasContinuousMotion && !entry.descriptor.requiresCapture)
    let renderer = try entry.makeRenderer(try TestGPU.context())
    #expect(renderer.animatesWithTime && !(renderer is any DesktopFrameSink)); renderer.stop()
    if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_CURRENT_ARTIFACTS"] ?? ProcessInfo.processInfo.environment["LUMA_CURRENT_ARTIFACTS"] {
        let directory = URL(fileURLWithPath: path); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for progress in [0.65, 1.0] {
            let pixels = try harness.render(.init(closure: progress, time: 2), width: 1440, height: 960).pixels
            let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
            let image = try #require(CGImage(width: 1440, height: 960, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 1440*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("Current-\(progress).png"))
        }
    }
}

@Test @MainActor func currentNativeResolutionFrameBudget() throws {
    let harness = try CurrentHarness()
    var times: [Double] = []
    for frame in 0..<8 {
        let result = try harness.render(.init(closure: 1, time: Double(frame)/60), width: 3024, height: 1964)
        if frame > 1 { times.append(result.gpuTime) }
    }
    let median = times.sorted()[times.count/2]
    print(String(format: "Current 3024×1964 GPU median: %.2f ms", median * 1000))
    #expect(median < 1.0/60)
}
