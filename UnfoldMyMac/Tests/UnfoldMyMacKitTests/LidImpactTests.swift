import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test(.requiresGPU, .tags(.gpu), arguments: LidImpactPipeline.Style.allCases)
@MainActor func lidImpactIsRadialReversibleAndPremultiplied(_ style: LidImpactPipeline.Style) throws {
    let pipeline = try LidImpactPipeline(style: style, gpu: try TestGPU.context())
    func render(_ closure: Double, time: Double = 2, strength: Double = 1, reduced: Bool = false,
                width: Int = 640, height: Int = 400) throws -> OffscreenFrame {
        try OffscreenRenderer.render(pipeline, frame: .init(closure: closure, parameters: .init(strength: strength),
            time: time, reduceMotion: reduced), width: width, height: height)
    }
    #expect(try render(0).pixels.allSatisfy { $0 == 0 })
    let onset = try render(0.004).pixels
    #expect(stride(from: 3, to: onset.count, by: 4).contains { onset[$0] > 0 })
    let half = try render(0.5)
    // Both begin in the middle, leaving opposite edges clear at half travel.
    #expect(half.pixels[(200 * 640 + 320) * 4 + 3] > 0)
    #expect(half.pixels[(200 * 640) * 4 + 3] == 0)
    #expect(half.pixels[(200 * 640 + 639) * 4 + 3] == 0)
    #expect(try render(0.5, strength: 0).pixels != half.pixels)
    #expect(stride(from: 0, to: half.pixels.count, by: 4).allSatisfy { i in
        (0..<3).allSatisfy { half.pixels[i + $0] <= half.pixels[i + 3] }
    })
    for (width, height) in [(640, 400), (300, 500), (1000, 300)] {
        let closed = try render(1, width: width, height: height).pixels
        #expect(stride(from: 3, to: closed.count, by: 4).allSatisfy { closed[$0] == 255 })
    }
    #expect(try render(0.5).pixels == half.pixels) // Reopen after full closure.
    let later = try render(0.5, time: 20).pixels
    #expect((later != half.pixels) == (style == .vortex))
    #expect(try render(0.5, time: 2, reduced: true).pixels == render(0.5, time: 20, reduced: true).pixels)
    let entry = try #require(EffectRegistry.builtIn().entry(for: EffectID(rawValue: style.rawValue)))
    #expect(!entry.descriptor.requiresCapture)
    #expect(entry.descriptor.hasContinuousMotion == (style == .vortex))
    if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_IMPACT_ARTIFACTS"] {
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for closure in [0.2, 0.5, 0.85, 1.0] {
            let image = try OffscreenRenderer.cgImage(render(closure, width: 1440, height: 900))
            let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent("\(style.rawValue)-\(closure).png"))
        }
    }
}

@Test(.requiresGPU, .tags(.gpu), arguments: LidImpactPipeline.Style.allCases)
@MainActor func lidImpactFitsNativeFrameBudget(_ style: LidImpactPipeline.Style) throws {
    let pipeline = try LidImpactPipeline(style: style, gpu: try TestGPU.context())
    var samples: [Double] = []
    for i in 0..<8 {
        let frame = try OffscreenRenderer.render(pipeline, frame: .init(closure: 0.8, time: Double(i) / 60), width: 3024, height: 1964)
        if i > 1 { samples.append(frame.gpuSeconds) }
    }
    let median = samples.sorted()[samples.count / 2]
    print("\(style.rawValue) native GPU median: \(median * 1000) ms")
    #expect(median < 1.0 / 60)
}
