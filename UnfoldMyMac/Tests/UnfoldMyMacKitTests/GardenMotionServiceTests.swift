import AppKit
import Testing
import IOKit.hid
import UnfoldMyMacCore
import SwiftUI
@testable import UnfoldMyMacKit

@MainActor final class GardenTestMotion: GardenMotionReading {
    var diagnostic = "Synthetic motion"
    var starts = 0, stops = 0
    var running = false
    var missing = false
    func start() { starts += 1; running = true }
    func stop() { if running { stops += 1 }; running = false }
    func read(now: Double) -> GardenMotionSample {
        .init(acceleration: running && !missing ? SIMD3(0,0,-1) : nil, rotation: running && !missing ? .zero : nil)
    }
}

@Test func gardenMotionCallbackDecodesSignedQ16AndExpiresStaleReadings() async {
    let report = GardenMotionReport()
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            var bytes = [UInt8](repeating: 0, count: 22)
            for (axis, value) in [Int32(65536), -32768, 0].enumerated() {
                let raw = UInt32(bitPattern: value)
                for byte in 0..<4 { bytes[6+axis*4+byte] = UInt8(truncatingIfNeeded: raw >> (byte*8)) }
            }
            bytes.withUnsafeMutableBufferPointer {
                GardenMotionReport.callback(Unmanaged.passUnretained(report).toOpaque(), 0, nil, kIOHIDReportTypeInput, 0, $0.baseAddress!, $0.count)
            }
            continuation.resume()
        }
    }
    let now = ProcessInfo.processInfo.systemUptime
    #expect(report.read(now: now) == SIMD3(1,-0.5,0))
    #expect(report.read(now: now+1) == nil)
    [UInt8](repeating: 0, count: 21).withUnsafeBufferPointer { report.receive($0, now: now+2) }
    #expect(report.read(now: now+2) == nil, "A malformed report must never become a reading")
}

@Test @MainActor func gardenMotionSharesVisibilityLeasesAndReleasesOnSleepStillAndOptOut() {
    let motion = GardenTestMotion()
    let service = WallpaperInputService(audio: GardenTestAudio(), makeSensor: { GardenTestLid() }, makeMotion: { motion })
    let a = UUID(), b = UUID()
    service.setConsumer(a, template: "hinge-garden", visible: true, animated: true)
    service.setConsumer(b, template: "hinge-garden", visible: true, animated: true)
    #expect(motion.starts == 1)
    service.removeConsumer(a)
    #expect(motion.running)
    service.configure(connections: [:], suspended: true, reducedMotion: false)
    #expect(!motion.running)
    service.configure(connections: [:], suspended: false, reducedMotion: false)
    #expect(motion.starts == 2)
    service.configure(connections: [:], suspended: false, reducedMotion: true)
    #expect(!motion.running)
    service.configure(connections: ["hinge-garden": ["garden": .init(motionSensors: false)]], suspended: false, reducedMotion: false)
    #expect(!motion.running)
    service.setConnections([:])
    #expect(motion.running)
    service.removeConsumer(b)
    #expect(!motion.running && !service.isSampling)
}

@Test func gardenMotionSettingsMigrateAndReduceMotionSuppressesPhysicalInputs() throws {
    let settings = try JSONDecoder().decode(WallpaperConnectionSettings.self, from: Data(#"{"enabled":false}"#.utf8))
    #expect(settings.pointerParallax && settings.sensorMotion && !settings.showsOneLiners && settings.changesLineOnBlow)
    #expect(settings.rotationInterval == 45)
    var smoother = WallpaperLiveInputSmoother()
    var target = UnfoldMyMacCore.WallpaperLiveInputs()
    target.parallax = SIMD2(100, .nan); target.motionStir = 100
    let moving = smoother.advance(toward: target, delta: 0.1, animating: true)
    #expect(moving.parallax.x > 0 && moving.parallax.x < 1.5 && moving.parallax.y == 0 && moving.motionStir < 1)
    let still = smoother.advance(toward: target, delta: 0.1, animating: false)
    #expect(still.parallax == .zero && still.motionStir == 0)
}

@Test @MainActor func gardenAtmospherePreviewCancelsAndSavedOptionsSurviveReload() async throws {
    let suite = "garden-atmosphere-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let audio = GardenTestAudio(), motion = GardenTestMotion()
    let service = WallpaperInputService(audio: audio, makeSensor: { GardenTestLid() }, makeMotion: { motion })
    let preferences = UserDefaultsPreferencesStore(defaults: defaults)
    let setup = WallpaperSetupController(preferences: preferences, inputs: service)
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == "hinge-garden" })
    service.setConsumer(UUID(), template: template.id, visible: true, animated: true)
    defer { service.stop() }
    setup.open(template)
    let edited = WallpaperConnectionSettings(parallax: false, motionSensors: false, oneLiners: true, lineInterval: 15, blowToChange: true)
    setup.setDraft(edited, for: "garden")
    try await settle { service.gardenQuote != nil }
    #expect(!motion.running && !audio.isRunning && audio.requests == 0)
    if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_GARDEN_ARTIFACTS"],
       let background = NSImage(contentsOfFile: path+"/open.png") {
        let content = WallpaperGardenQuote(inputs: service).frame(width: 1512, height: 982)
            .background(Image(nsImage: background).resizable())
        let renderer = ImageRenderer(content: content); renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path+"/one-liner.png"))
    }
    setup.cancel()
    #expect(service.gardenQuote == nil && motion.running)
    setup.open(template); setup.setDraft(edited, for: "garden"); setup.finish()
    let reloaded = WallpaperSetupController(preferences: preferences)
    #expect(reloaded.configuration("garden", for: template.id) == edited)
}
