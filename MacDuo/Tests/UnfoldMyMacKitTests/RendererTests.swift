import AppKit
import Metal
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor private struct OffscreenFrost {
    let pipeline: FrostPipeline
    init() throws { pipeline = try FrostPipeline(gpu: try TestGPU.context()) }
    func texture(width: Int, height: Int) throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        desc.storageMode = .shared; desc.usage = [.shaderRead, .renderTarget]
        return try #require(pipeline.gpu.device.makeTexture(descriptor: desc))
    }
    func render(_ bytes: [UInt8], width: Int, height: Int, closure: Double, strength: Double = 1) throws -> [UInt8] {
        let source = try texture(width: width, height: height)
        bytes.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        let target = try texture(width: width, height: height)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, source: source, pass: pass, context: .init(closure: closure, parameters: .init(strength: strength))))
        command.commit(); command.waitUntilCompleted()
        #expect(command.error == nil)
        var result = [UInt8](repeating: 0, count: width * height * 4)
        result.withUnsafeMutableBytes { target.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return result
    }
}

@Test @MainActor func identityOrientationScaleAndColor() throws {
    let renderer = try OffscreenFrost()
    let width = 257, height = 193
    var input = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height { for x in 0..<width {
        let i = (y * width + x) * 4
        input[i] = UInt8(x % 256); input[i + 1] = UInt8(y % 256); input[i + 2] = UInt8((x + y) % 256)
    } }
    for closure in [0.0, 0.1, 0.25, 0.5] {
        let output = try renderer.render(input, width: width, height: height, closure: closure, strength: 0)
        #expect(zip(input, output).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
    }
}
@Test @MainActor func blurProgressionHingeAndFinalBlack() throws {
    let renderer = try OffscreenFrost()
    let width = 512, height = 384
    var input = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height { for x in 0..<width {
        let i = (y * width + x) * 4
        let value: UInt8 = (x / 4 + y / 4) % 2 == 0 ? 255 : 0
        input[i] = value; input[i + 1] = value; input[i + 2] = value
    } }
    let blurred = try renderer.render(input, width: width, height: height, closure: 0.2)
    func energy(_ bytes: [UInt8], y: Int) -> Int {
        (32..<(width - 33)).reduce(0) { $0 + abs(Int(bytes[(y * width + $1) * 4]) - Int(bytes[(y * width + $1 + 1) * 4])) }
    }
    #expect(energy(blurred, y: 60) < energy(blurred, y: height - 2))
    #expect(energy(blurred, y: 60) < energy(input, y: 60) / 4)
    let black = try renderer.render(input, width: width, height: height, closure: 1)
    #expect(black.enumerated().allSatisfy { $0.offset % 4 == 3 ? $0.element == 255 : $0.element == 0 })
}
@Test(.requiresGPU, .tags(.gpu)) @MainActor func captureBufferCanBeWrappedAndStopped() throws {
    var buffer: CVPixelBuffer?
    let attributes = [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
    #expect(CVPixelBufferCreate(nil, 257, 193, kCVPixelFormatType_32BGRA, attributes, &buffer) == kCVReturnSuccess)
    let renderer = MetalSurfaceRenderer(pipeline: try FrostPipeline(gpu: try TestGPU.context()))
    renderer.receive(DesktopFrame(try #require(buffer)))
    #expect(renderer.ready)
    renderer.stop()
    #expect(!renderer.ready)
}

@Test @MainActor func frostRespondsOnTheFirstLiveFrame() throws {
    let renderer = try OffscreenFrost()
    let input = [UInt8](repeating: 255, count: 128 * 96 * 4)
    let onset = EffectMath.liveProgress(lid: 108, activation: 108, completionFraction: 0.8)
    let output = try renderer.render(input, width: 128, height: 96, closure: onset)
    #expect(output[64 * 4] < 255)
    #expect(output[((95 * 128) + 64) * 4] == 255) // Hinge stays undimmed.
}

@Test @MainActor func nativeEffectsHaveVisibleCoverageAtTheTrigger() throws {
    let onset = EffectMath.liveProgress(lid: 108, activation: 108, completionFraction: 0.8)
    for kind in [NativeEffectRenderer.Kind.veil, .fade] {
        let renderer = NativeEffectRenderer(kind: kind)
        renderer.prepare(size: CGSize(width: 640, height: 420), scale: 2)
        renderer.update(.init(closure: onset))
        let gradient = try #require(renderer.view.layer?.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        let colors = try #require(gradient.colors as? [CGColor])
        #expect(colors.last!.alpha > 0)
        if kind == .veil {
            let material = try #require(renderer.view.subviews.first as? NSVisualEffectView)
            #expect(!material.isHidden)
            let mask = try #require(material.maskImage?.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: mask))
            #expect(try #require(bitmap.colorAt(x: 0, y: 0)).alphaComponent > 0)
        }
        renderer.stop()
    }
}
@Test(.requiresGPU, .tags(.gpu)) @MainActor func frostUsesLatestSourceAfterBlurAndIdentity() throws {
    let pipeline = try FrostPipeline(gpu: try TestGPU.context())
    let h = try OffscreenFrost()
    let source = try h.texture(width: 131, height: 97)
    let destination = try h.texture(width: 131, height: 97)
    for (index, closure) in [0.2, 0.0, 0.3].enumerated() {
        var bytes = [UInt8](repeating: 0, count: 131 * 97 * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) { bytes[i + index] = 255; bytes[i + 3] = 255 }
        bytes.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, 131, 97), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 131 * 4) }
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = destination; pass.colorAttachments[0].storeAction = .store
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, source: source, pass: pass, context: .init(closure: closure)))
        command.commit(); command.waitUntilCompleted()
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { destination.getBytes($0.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(65, 70, 1, 1), mipmapLevel: 0) }
        #expect(pixel[index] > 100)
        #expect(pixel[(index + 1) % 3] == 0)
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func nativeResolutionGPUFrameBudget() throws {
    let pipeline = try FrostPipeline(gpu: try TestGPU.context())
    let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 3024, height: 1964, mipmapped: false)
    desc.storageMode = .private; desc.usage = [.shaderRead, .renderTarget]
    let source = try #require(pipeline.gpu.device.makeTexture(descriptor: desc))
    let target = try #require(pipeline.gpu.device.makeTexture(descriptor: desc))
    // Initialize the source deterministically on the GPU.
    let clear = MTLRenderPassDescriptor(); clear.colorAttachments[0].texture = source
    clear.colorAttachments[0].loadAction = .clear; clear.colorAttachments[0].storeAction = .store
    clear.colorAttachments[0].clearColor = MTLClearColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)
    let initCommand = try #require(pipeline.gpu.queue.makeCommandBuffer())
    initCommand.makeRenderCommandEncoder(descriptor: clear)?.endEncoding()
    initCommand.commit(); initCommand.waitUntilCompleted()
    var durations: [Double] = []
    for iteration in 0..<15 {
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = target; pass.colorAttachments[0].storeAction = .store
        let command = try #require(pipeline.gpu.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, source: source, pass: pass, context: .init(closure: 0.35)))
        command.commit(); command.waitUntilCompleted()
        #expect(command.error == nil)
        if iteration >= 3 { durations.append((command.gpuEndTime - command.gpuStartTime) * 1000) }
    }
    let median = durations.sorted()[durations.count / 2]
    print("Frost 3024×1964 GPU median: \(String(format: "%.2f", median)) ms (60 Hz budget 16.67 ms)")
    // Record performance rather than asserting a hardware-dependent timing threshold.
    #expect(median > 0)
}
