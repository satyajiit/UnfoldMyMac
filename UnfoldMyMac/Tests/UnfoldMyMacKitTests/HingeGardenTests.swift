import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor func gardenTestPipeline() throws -> WallpaperPipeline {
    let catalog = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == "hinge-garden" }, "\(registry.errors)")
    return try WallpaperPipeline(template: template, gpu: TestGPU.context(), shaders: catalog)
}

@Test func gardenSettingsDecodeExistingConnectionsWithoutChangingTheirDefaults() throws {
    let old = try JSONDecoder().decode(WallpaperConnectionSettings.self, from: Data(#"{"enabled":false}"#.utf8))
    #expect(old.soundSensitivity == 1 && !old.enabled)
    #expect(WallpaperConnectionSettings(enabled: true, sensitivity: .nan).soundSensitivity == 1)
}

@Test func gardenRetreatReversesContinuouslyAndReduceMotionHoldsAComposedStill() {
    var smoother = WallpaperFrameSmoother(stillTime: 18)
    smoother.targetLiveInputs.lidOpen = 0
    let retreat = (0..<20).map { _ in smoother.advance(delta: 1.0/60, animating: true).liveInputs.lidOpen }
    #expect(zip(retreat,retreat.dropFirst()).allSatisfy { $0 >= $1 })
    smoother.targetLiveInputs.lidOpen = 1
    let reversal = smoother.advance(delta: 1.0/60, animating: true).liveInputs.lidOpen
    #expect(reversal > retreat.last! && reversal - retreat.last! < 0.08)
    smoother.targetLiveInputs.sound = 1; smoother.targetLiveInputs.pollen = 0
    let still = smoother.advance(delta: 1, animating: false)
    #expect(still.time == 18 && still.liveInputs.lidOpen == 1 && still.liveInputs.sound == 0 && still.liveInputs.pollen == -1)
    #expect(smoother.advance(delta: 5, animating: false) == still)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func hingeGardenReferenceFrames() throws {
    let pipeline = try gardenTestPipeline()
    #expect(pipeline.surface.maximumDimension == nil && pipeline.usesLiveInputs)
    #expect(pipeline.template.contentCollection == .scenes && pipeline.template.category == "nature" && pipeline.template.layers.isEmpty)
    var open = WallpaperLiveInputs()
    open.daylight = 0.35
    var closed = open; closed.lidOpen = 0
    var day = open; day.daylight = 1
    var night = open; night.daylight = 0
    var low = open; low.battery = 0.05
    var connected = open; connected.externalPower = 1; connected.battery = 1
    var connectedStill = connected; connectedStill.reducedMotion = true
    var charge = connected; charge.charging = 5.8
    var water = open; water.charging = 0.5
    var roots = open; roots.charging = 2.4
    var climb = open; climb.charging = 3.9
    var left = open; left.parallax = SIMD2(-1.5, 1)
    var right = open; right.parallax = SIMD2(1.5, -1)
    var sound = open; sound.sound = 1; sound.pollen = 0.8
    var still = open; still.reducedMotion = true
    let poses = [("open",open),("retracted",closed),("day",day),("night",night),("low-battery",low),
                 ("charging",charge),("sound",sound),("reduce-motion",still),("charge-water",water),
                 ("charge-roots",roots),("charge-climb",climb),("parallax-left",left),("parallax-right",right),
                 ("plugged-in",connected),("plugged-in-reduce-motion",connectedStill)]
    let directory = ProcessInfo.processInfo.environment["UNFOLDMYMAC_GARDEN_ARTIFACTS"].map { URL(fileURLWithPath: $0) }
    if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    var hashes = Set<String>()
    for (name, live) in poses {
        let frame = WallpaperFrame(time: 18, energy: 0.2, liveInputs: live)
        let rendered = try OffscreenRenderer.render(pipeline, frame: frame, width: directory == nil ? 640 : 3024, height: directory == nil ? 400 : 1964)
        hashes.insert(rendered.sha256)
        #expect(stride(from: 3, to: rendered.pixels.count, by: 4).allSatisfy { rendered.pixels[$0] == 255 })
        print(String(format: "GARDEN %@ %d×%d GPU %.2f ms",name,rendered.width,rendered.height,rendered.gpuSeconds*1000))
        if let directory { try writeGardenFrame(rendered, to: directory.appendingPathComponent(name+".png")) }
    }
    #expect(hashes.count >= 7)
    if let directory {
        for (name,w,h) in [("widescreen",2560,1440),("ultrawide",3440,1440),("portrait",1440,2560)] {
            let rendered = try OffscreenRenderer.render(pipeline, frame: .init(time: 18, energy: 0.2), width: w, height: h)
            try writeGardenFrame(rendered, to: directory.appendingPathComponent(name+".png"))
        }
        if ProcessInfo.processInfo.environment["UNFOLDMYMAC_GARDEN_MOTION"] == "1" {
            try renderGardenMotion(pipeline, directory: directory)
        }
        let cover = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(pose: pipeline.template.coverPose), width: 1280, height: 800)
        try writeGardenFrame(cover, to: directory.appendingPathComponent("cover.png"))
    }
}

@MainActor private func writeGardenFrame(_ frame: OffscreenFrame, to url: URL) throws {
    let bitmap = NSBitmapImageRep(cgImage: try OffscreenRenderer.cgImage(frame))
    try #require(bitmap.representation(using: .png, properties: [:])).write(to: url)
}

@Test func gardenUniformLayoutPreservesTheExistingShaderPrefix() {
    #expect(MemoryLayout<WallpaperUniforms>.stride == 144)
    #expect(MemoryLayout<WallpaperUniforms>.offset(of: \.params) == 64)
    #expect(MemoryLayout<WallpaperUniforms>.offset(of: \.interaction) == 96)
    #expect(MemoryLayout<WallpaperUniforms>.offset(of: \.environment) == 112)
    #expect(MemoryLayout<WallpaperUniforms>.offset(of: \.motion) == 128)
}

@Test func gardenPulseAgesInterpolateAtDisplayCadenceWithoutAccumulating() {
    var smoother = WallpaperLiveInputSmoother(), target = WallpaperLiveInputs()
    target.pollen = 0; target.charging = 0
    let first = smoother.advance(toward: target, delta: 1.0/60, animating: true)
    let next = smoother.advance(toward: target, delta: 1.0/60, animating: true)
    #expect(first.pollen == 0 && next.pollen > 0 && next.charging > 0)
    target.pollen = -1; target.charging = -1
    let cleared = smoother.advance(toward: target, delta: 10000, animating: true)
    #expect(cleared.pollen == -1 && cleared.charging == -1)
}

@Test func gardenConnectedLightFadesSmoothlyAndRemainsAvailableInReduceMotion() {
    var smoother = WallpaperLiveInputSmoother(), target = WallpaperLiveInputs()
    target.externalPower = 1
    let rising = (0..<180).map { _ in smoother.advance(toward: target, delta: 1.0/60, animating: true).externalPower }
    #expect(rising[0] > 0 && rising[0] < 0.05 && rising.last! > 0.99)
    #expect(zip(rising, rising.dropFirst()).allSatisfy { $0 <= $1 })
    target.externalPower = 0
    let falling = (0..<180).map { _ in smoother.advance(toward: target, delta: 1.0/60, animating: true).externalPower }
    #expect(falling[0] > 0.95 && falling.last! < 0.01)
    #expect(zip(falling, falling.dropFirst()).allSatisfy { $0 >= $1 })
    target.externalPower = 1
    let still = smoother.advance(toward: target, delta: 1000, animating: false)
    #expect(still.externalPower == 1 && still.charging == -1)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func gardenLightStaysOnAfterChargingPulseFinishes() throws {
    let pipeline = try gardenTestPipeline()
    var dynamics = WallpaperInputDynamics()
    for tick in 0...360 {
        dynamics.sample(now: Double(tick)/30, lidAngle: 110, rms: 0, sensitivity: 1, battery: 1,
                        pluggedIn: tick > 0, daylight: 0.35, soundEnabled: false, reducedMotion: false)
    }
    #expect(dynamics.value.charging == -1)
    let connected = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(time: 18, liveInputs: dynamics.value), width: 640, height: 400)
    var endOfPulse = dynamics.value; endOfPulse.charging = 8.99
    let ending = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(time: 18, liveInputs: endOfPulse), width: 640, height: 400)
    #expect(connected.sha256 == ending.sha256, "Expiring the pulse must not extinguish the light")
    var disconnected = dynamics.value; disconnected.externalPower = 0
    let unpowered = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(time: 18, liveInputs: disconnected), width: 640, height: 400)
    #expect(connected.pixels.reduce(0) { $0 + Int($1) } > unpowered.pixels.reduce(0) { $0 + Int($1) })
    var still = dynamics.value; still.reducedMotion = true
    let reduced = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(time: 18, liveInputs: still), width: 640, height: 400)
    still.externalPower = 0
    let reducedUnpowered = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(time: 18, liveInputs: still), width: 640, height: 400)
    #expect(reduced.pixels.reduce(0) { $0 + Int($1) } > reducedUnpowered.pixels.reduce(0) { $0 + Int($1) })
}
