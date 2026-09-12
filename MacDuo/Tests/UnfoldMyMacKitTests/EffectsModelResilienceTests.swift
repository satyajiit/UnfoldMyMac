import AppKit
import CoreVideo
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

// L1: turning effects on while a preview runs must survive the preview ending.
@Test @MainActor func enablingDuringAPreviewSurvivesStoppingThePreview() {
    let store = FakeStore(); store.value.effect = .fade
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), makeCapture: { FakeCapture() })
    let model = UnfoldMyMacModel(store: store, registry: registry, sensorFactory: { FakeSensor() }, displays: FakeDisplay(), session: session, clock: { 0 })
    defer { model.shutdown() }
    #expect(!model.enabled)
    model.beginPreview(effect: .veil)
    model.setEnabled(true)
    #expect(model.isPreviewing, "Enabling does not interrupt the preview")
    model.stopPreview()
    #expect(model.enabled && !model.isPreviewing)
    model.beginPreview(effect: .veil)
    model.setEnabled(false)
    #expect(!model.isPreviewing && !model.enabled, "Turning off ends the preview as well")
}

// L2: a missing sensor is reopened with exponential backoff, and a successful read resets it.
@Test @MainActor func sensorReconnectBacksOffExponentiallyAndResetsAfterAReading() {
    let sensor = FakeSensor(); sensor.angle = nil
    var constructions = 0
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), makeCapture: { FakeCapture() })
    var now = 0.0
    let model = UnfoldMyMacModel(store: FakeStore(), registry: registry, sensorFactory: { constructions += 1; return sensor }, displays: FakeDisplay(), session: session, clock: { now })
    defer { model.shutdown() }
    #expect(constructions == 1)
    model.tick(); #expect(constructions == 2, "First failed read reconnects immediately")
    for t in stride(from: 0.5, through: 3.5, by: 0.5) { now = t; model.tick() }
    #expect(constructions == 2, "No second attempt within four seconds")
    now = 4; model.tick(); #expect(constructions == 3)
    now = 8; model.tick(); #expect(constructions == 3)
    now = 12; model.tick(); #expect(constructions == 4)
    now = 28; model.tick(); #expect(constructions == 5)
    now = 60; model.tick(); #expect(constructions == 6)
    now = 119; model.tick(); #expect(constructions == 6, "Backoff is capped at one minute")
    now = 120; model.tick(); #expect(constructions == 7)
    sensor.angle = 90; now = 121; model.tick()
    #expect(model.sensorAvailable)
    sensor.angle = nil; now = 123; model.tick()
    #expect(constructions == 8, "A good reading resets the delay to two seconds")
}

// P16: a card preview that fails ends the preview but keeps the chosen effect running.
@Test @MainActor func aFailedPreviewOfAnotherEffectKeepsTheChosenEffectRunning() async throws {
    let store = FakeStore(); store.value.effect = .fade
    let capture = FakeCapture(); capture.failure = CaptureFailure.exclusionUnavailable
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), makeCapture: { capture })
    var now = 0.0
    let model = UnfoldMyMacModel(store: store, registry: registry, sensorFactory: { FakeSensor() }, displays: FakeDisplay(), session: session, clock: { now })
    defer { model.shutdown() }
    model.setEnabled(true); now = 0.6; model.tick()
    #expect(session.renderer != nil && model.enabled)
    model.togglePreview(for: .frost)
    now = 1.2; model.tick() // display safety needs half a second of readiness before the session starts
    for _ in 0..<20 { await Task.yield() }
    #expect(!model.isPreviewing)
    #expect(model.enabled, "The user's enabled state survives a failed preview")
    #expect(model.errorMessage != nil)
    now = 1.8; model.tick()
    #expect(session.renderer != nil, "The chosen effect resumed")
    model.selectEffect(.frost); now = 2.4; model.tick()
    for _ in 0..<20 { await Task.yield() }
    #expect(!model.enabled && session.renderer == nil, "The chosen effect itself failing turns effects off")
}

// L10: duplicate registrations are reported, not fatal.
@Test @MainActor func registryIgnoresDuplicateEntriesAndReportsThem() {
    let entry = EffectRegistration(descriptor: .init(id: .veil, title: "Veil", subtitle: "", detail: "", symbol: "circle"), makeRenderer: { FakeRenderer() })
    let registry = EffectRegistry(entries: [entry, entry])
    #expect(registry.entries.count == 1)
    #expect(registry.diagnostics == ["Duplicate effect ‘veil’ was ignored."])
}

// P8: hiding an already hidden panel is a no-op rather than a window-server round trip every frame.
@Test(.requiresWindowServer, .tags(.window)) @MainActor func effectHostOnlyOrdersOutAVisiblePanel() {
    let host = EffectHost()
    #expect(!host.isVisible)
    host.hide(); #expect(!host.isVisible)
    host.show(); #expect(host.isVisible)
    host.hide(); #expect(!host.isVisible)
    host.hide(); #expect(!host.isVisible)
}

// L7: stopping releases the wrapped capture texture and the per-slot mip chains.
@Test(.requiresGPU, .tags(.gpu)) @MainActor func frostRendererReleasesCaptureTexturesOnStopAndResize() throws {
    var buffer: CVPixelBuffer?
    let attributes = [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
    #expect(CVPixelBufferCreate(nil, 64, 48, kCVPixelFormatType_32BGRA, attributes, &buffer) == kCVReturnSuccess)
    let renderer = FrostRenderer(pipeline: try FrostPipeline())
    renderer.prepare(size: CGSize(width: 64, height: 48), scale: 1)
    renderer.receive(DesktopFrame(try #require(buffer)))
    #expect(renderer.ready)
    renderer.prepare(size: CGSize(width: 32, height: 24), scale: 1)
    #expect(!renderer.ready, "A resized display invalidates the captured frame")
    renderer.receive(DesktopFrame(try #require(buffer)))
    renderer.stop()
    #expect(!renderer.ready)
}
