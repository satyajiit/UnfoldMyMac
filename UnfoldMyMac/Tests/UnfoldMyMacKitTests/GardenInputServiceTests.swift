import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor final class GardenTestAudio: WallpaperAudioCapturing {
    var permission = WallpaperMicrophonePermission.undetermined
    var isRunning = false
    var starts = 0, stops = 0, requests = 0
    var missing = false
    var onDeviceChange: (() -> Void)?
    func requestPermission() async {
        requests += 1
        if permission == .undetermined { permission = .denied }
    }
    func start() throws {
        if missing { throw CocoaError(.fileReadNoSuchFile) }
        isRunning = true; starts += 1
    }
    func stop() { if isRunning { stops += 1 }; isRunning = false }
    func amplitude(now: Double) -> Double { isRunning ? 0.1 : 0 }
}
@MainActor final class GardenTestLid: LidReading {
    var diagnostic = "Test sensor"
    var value: Double? = 100
    func read() -> Double? { value }
}

@Test @MainActor func gardenCaptureSharesOneSessionAndReleasesItOnVisibilitySleepAndDisable() async throws {
    let audio = GardenTestAudio(), lid = GardenTestLid()
    let service = WallpaperInputService(audio: audio, makeSensor: { lid }, makeMotion: { GardenTestMotion() })
    let a = UUID(), b = UUID()
    let connections = ["hinge-garden": ["microphone": WallpaperConnectionSettings(enabled: true)]]
    service.configure(connections: connections, suspended: false, reducedMotion: false)
    service.setConsumer(a, template: "hinge-garden", visible: true, animated: true)
    #expect(audio.starts == 0 && audio.requests == 0)
    service.requestMicrophonePermission()
    try await settle { service.permission == .denied }
    #expect(audio.starts == 0 && service.isSampling)
    audio.permission = .authorized
    service.configure(connections: connections, suspended: false, reducedMotion: false)
    service.setConsumer(b, template: "hinge-garden", visible: true, animated: true)
    #expect(audio.starts == 1 && service.consumerCount == 2)
    service.removeConsumer(a)
    #expect(audio.isRunning)
    audio.onDeviceChange?()
    #expect(audio.starts == 2 && audio.stops == 1)
    service.configure(connections: connections, suspended: true, reducedMotion: false)
    #expect(!audio.isRunning && !service.isSampling)
    service.configure(connections: connections, suspended: false, reducedMotion: false)
    #expect(audio.isRunning)
    service.configure(connections: connections, suspended: false, reducedMotion: true)
    #expect(!audio.isRunning)
    service.configure(connections: [:], suspended: false, reducedMotion: false)
    #expect(!audio.isRunning)
    service.removeConsumer(b)
    #expect(!service.isSampling)
    audio.missing = true
    service.configure(connections: connections, suspended: false, reducedMotion: false)
    service.setConsumer(a, template: "hinge-garden", visible: true, animated: true)
    #expect(!audio.isRunning && service.audioStatus.contains("No microphone"))
    service.stop()
    #expect(!service.isSampling && service.consumerCount == 0)
}

@Test @MainActor func gardenLidMonitorForgetsStaleReadingsAndReconnects() {
    let sensor = GardenTestLid()
    var creations = 0
    let monitor = LidMonitor(makeSensor: { creations += 1; return sensor })
    monitor.read(now: 0)
    #expect(monitor.angle == 100)
    sensor.value = nil
    monitor.read(now: 10)
    #expect(monitor.angle == nil && creations > 1)
    #expect(WallpaperLiveInputs.openness(angle: monitor.angle) == 1)
    monitor.reopen(); sensor.value = 60; monitor.read(now: 11)
    #expect(monitor.angle == 60)
}

@Test(.requiresGPU, .requiresWindowServer, .tags(.gpu, .window)) @MainActor
func gardenCaptureFollowsSurfaceVisibilityAfterWindowAttachment() async throws {
    let audio = GardenTestAudio(); audio.permission = .authorized
    let service = WallpaperInputService(audio: audio, makeSensor: { GardenTestLid() }, makeMotion: { GardenTestMotion() })
    service.configure(connections: ["hinge-garden": ["microphone": .init(enabled: true)]], suspended: false, reducedMotion: false)
    let renderer = WallpaperSurfaceRenderer(pipeline: try gardenTestPipeline(), inputs: service)
    renderer.configure(.init(), framesPerSecond: 60)
    #expect(!audio.isRunning, "A renderer without a visible window must not own capture")
    let window = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 600, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = renderer.surfaceView
    defer { renderer.stop(); window.orderOut(nil); window.close(); service.stop() }
    // Inject the view visibility notification: the command-line suite owns no NSApplication event loop.
    renderer.surfaceView.onVisibilityChanged?(true)
    #expect(service.consumerCount == 1 && audio.starts == 1, "visible=\(window.isVisible), occlusion=\(window.occlusionState.rawValue), paused=\(renderer.isPaused), consumers=\(service.consumerCount), starts=\(audio.starts)")
    renderer.surfaceView.onVisibilityChanged?(false)
    #expect(!service.isSampling)
}

@Test @MainActor func gardenSoundDraftTakesEffectImmediatelyAndCancelRestoresSavedOptOut() throws {
    let suite = "garden-sound-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let audio = GardenTestAudio(); audio.permission = .authorized
    let service = WallpaperInputService(audio: audio, makeSensor: { GardenTestLid() }, makeMotion: { GardenTestMotion() })
    let setup = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults), inputs: service)
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == "hinge-garden" })
    service.setConsumer(UUID(), template: template.id, visible: true, animated: true)
    defer { service.stop() }
    setup.open(template)
    #expect(!audio.isRunning)
    setup.setDraft(.init(enabled: true, sensitivity: 2), for: "microphone")
    #expect(audio.isRunning && !setup.configuration("microphone", for: template.id).enabled)
    setup.setDraft(.init(enabled: false), for: "microphone")
    #expect(!audio.isRunning)
    setup.setDraft(.init(enabled: true), for: "microphone")
    setup.cancel()
    #expect(!audio.isRunning && !setup.configuration("microphone", for: template.id).enabled)
}
