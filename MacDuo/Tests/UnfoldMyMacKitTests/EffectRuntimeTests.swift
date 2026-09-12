import AppKit
import CoreVideo
import Observation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

// P7: steady ticks must not invalidate observers of the status.
@Test @MainActor func identicalTicksDoNotInvalidateStatusObservers() {
    let store = InMemoryPreferencesStore(); store.settings.effect = .fade
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let sensor = FakeSensor(); sensor.angle = 150
    var now = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, session: session, clock: { now })
    defer { model.shutdown() }
    model.setEnabled(true); now = 0.6; model.tick()
    #expect(model.status == "Ready · close to 125°")
    let invalidations = Mutex(0)
    withObservationTracking { _ = model.status; _ = model.angleLabel; _ = model.displayName } onChange: { invalidations.withLock { $0 += 1 } }
    for _ in 0..<100 { now += 1.0 / 30; model.tick(); model.renderFrame(deltaTime: 1.0 / 60) }
    #expect(invalidations.withLock { $0 } == 0)
    model.setEnabled(false)
    #expect(invalidations.withLock { $0 } == 1)
}

// L9: the status names the effect on screen, which is Fade under Reduce Transparency.
@Test @MainActor func statusNamesTheRenderedEffectUnderReduceTransparency() {
    let store = InMemoryPreferencesStore(); store.settings.effect = .frost
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let environment = FakeSystemEnvironment(); environment.state.reduceTransparency = true
    let sensor = FakeSensor(); sensor.angle = 100
    var now = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, session: session, environment: environment, clock: { now })
    model.start(); defer { model.shutdown() }
    model.setEnabled(true); now = 0.6; model.tick()
    #expect(session.renderedEffect == .fade)
    #expect(model.status == "fade active")
    #expect(model.selectedEffect.id == .frost && model.activeEffect.id == .frost)
}

// L3: the poll timer follows what is rendering or shown instead of running at 30 Hz forever.
@Test @MainActor func pollingRateFollowsEnabledPreviewAndAngleVisibility() {
    let store = InMemoryPreferencesStore(); store.settings.effect = .fade; store.settings.showAngle = false
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let environment = FakeSystemEnvironment()
    let model = makeModel(store: store, registry: registry, session: session, environment: environment)
    let pacing = model.runtime.pacing
    #expect(pacing.pollingInterval == nil, "Nothing polls before start")
    model.start(); defer { model.shutdown() }
    #expect(pacing.pollingInterval == nil, "Off, angle hidden, window closed: no timer at all")
    model.setWindowVisible(true)
    #expect(pacing.pollingInterval == LidPollingPolicy.idleInterval)
    model.setWindowVisible(false)
    #expect(pacing.pollingInterval == nil)
    model.setShowAngle(true)
    #expect(pacing.pollingInterval == LidPollingPolicy.idleInterval)
    model.setEnabled(true)
    #expect(pacing.pollingInterval == LidPollingPolicy.liveInterval)
    model.setEnabled(false)
    #expect(pacing.pollingInterval == LidPollingPolicy.idleInterval)
    model.togglePreview(for: .rise)
    #expect(pacing.pollingInterval == LidPollingPolicy.liveInterval)
    model.stopPreview()
    #expect(pacing.pollingInterval == LidPollingPolicy.idleInterval)
    environment.state.systemAsleep = true
    model.runtime.tick()
    model.setShowAngle(false)
    #expect(pacing.pollingInterval == nil)
}

// L12: capture telemetry survives restarts of the same effect and resets for a new one.
@Test(.requiresWindowServer, .tags(.window)) @MainActor func captureFramesResetOnlyWhenTheEffectChanges() throws {
    let screen = try #require(NSScreen.screens.first)
    let capture = FakeCapture()
    let session = EffectSession(registry: makeRegistry(), host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { capture })
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, 2, 2, kCVPixelFormatType_32BGRA, nil, &buffer)
    let frame = DesktopFrame(try #require(buffer))
    for _ in 0..<3 { capture.onFrame?(frame) }
    #expect(session.captureFrames == 3)
    session.stop()
    #expect(session.captureFrames == 3)
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    #expect(session.captureFrames == 3)
    session.start(effect: .veil, screen: screen, reduceTransparency: false)
    #expect(session.captureFrames == 0)
    session.stop()
}

// A preview suspends the chosen effect's renderer and hands it back when the preview ends.
@Test @MainActor func endingAPreviewReinstallsTheSuspendedRenderer() {
    let store = InMemoryPreferencesStore(); store.settings.effect = .fade
    var created: [FakeRenderer] = []
    let registry = makeRegistry { _, renderer in created.append(renderer) }
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var now = 0.0
    let model = makeModel(store: store, registry: registry, session: session, clock: { now })
    defer { model.shutdown() }
    model.setEnabled(true); now = 0.6; model.tick()
    #expect(created.count == 1 && session.renderer === created[0])
    model.togglePreview(for: .rise)
    #expect(session.hasRetainedRenderer)
    now = 1.2; model.tick()
    #expect(created.count == 2 && session.renderer === created[1])
    model.togglePreview(for: .curtains); now = 1.8; model.tick()
    #expect(created.count == 3 && session.hasRetainedRenderer, "Switching previews keeps the chosen effect's renderer")
    model.stopPreview(); now = 2.4; model.tick()
    #expect(created.count == 3, "The chosen effect came back without a rebuild")
    #expect(session.renderer === created[0] && !session.hasRetainedRenderer)
    #expect(model.enabled && model.status == "fade active")
    model.togglePreview(for: .rise); now = 3; model.tick()
    model.selectEffect(.curtains)
    #expect(!session.hasRetainedRenderer, "A new selection drops the suspended renderer")
    model.setEnabled(false)
    #expect(session.renderer == nil && !session.hasRetainedRenderer)
}

// P3: a new capture only starts once the previous one has finished stopping.
@Test(.requiresWindowServer, .tags(.window)) @MainActor func aNewCaptureWaitsForThePreviousTeardown() async throws {
    let screen = try #require(NSScreen.screens.first)
    var trace: [String] = []
    let session = EffectSession(registry: makeRegistry(), host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: {
        let capture = FakeCapture(); capture.stopYields = 5; capture.trace = { trace.append($0) }; return capture
    })
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    for _ in 0..<10 { await Task.yield() }
    session.start(effect: .veil, screen: screen, reduceTransparency: false)
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    for _ in 0..<40 { await Task.yield() }
    #expect(trace == ["start", "stop", "start"])
    session.stop()
    for _ in 0..<40 { await Task.yield() }
    #expect(trace == ["start", "stop", "start", "stop"])
}

// P15: slider writes coalesce; discrete choices and flushes write at once.
@Test @MainActor func persistenceSchedulerCoalescesAndFlushes() async throws {
    let scheduler = PersistenceScheduler(delay: .milliseconds(40))
    var writes = 0
    for _ in 0..<5 { scheduler.schedule { writes += 1 } }
    #expect(writes == 0)
    try await settle { writes == 1 }
    scheduler.schedule { writes += 1 }
    scheduler.flush()
    #expect(writes == 2)
    scheduler.flush()
    #expect(writes == 2, "Nothing pending")
    try await Task.sleep(for: .milliseconds(80))
    #expect(writes == 2, "A flushed write does not fire again")
    let immediate = PersistenceScheduler(delay: .zero)
    immediate.schedule { writes += 1 }
    #expect(writes == 3)
}

@Test @MainActor func effectPreferencesCoalesceSliderWritesButPersistChoicesAtOnce() async throws {
    let store = InMemoryPreferencesStore()
    let registry = makeRegistry()
    let preferences = EffectPreferences(store: store, registry: registry, artworkLoadFailed: false, scheduler: PersistenceScheduler(delay: .milliseconds(30)))
    preferences.select(.veil)
    #expect(store.settings.effect == .veil)
    preferences.setActivation(100); preferences.setActivation(110); preferences.setStrength(0.4)
    #expect(preferences.settings.activation == 110 && store.settings.activation == EffectMath.defaultActivation)
    #expect(store.settings.parameters[EffectID.veil.rawValue] == nil)
    try await settle { store.settings.activation == 110 }
    #expect(store.settings.parameters[EffectID.veil.rawValue]?.strength == 0.4)
    preferences.setCompletionFraction(0.5); preferences.flush()
    #expect(store.settings.completionFraction == 0.5)
}

@Test @MainActor func coverImageStoreDecodesOnceAndIgnoresMissingFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("covers-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("cover.png")
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 6, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    try #require(bitmap?.representation(using: .png, properties: [:])).write(to: url)
    let store = CoverImageStore(countLimit: 4)
    #expect(store.cached(url) == nil)
    let first = try #require(await store.image(for: url))
    #expect(first.size.width == 8 && first.size.height == 6)
    #expect(store.cached(url) === first)
    #expect(await store.image(for: url) === first)
    #expect(await store.image(for: directory.appendingPathComponent("missing.png")) == nil)
}

@Test func latestFrameBoxKeepsOnlyTheNewestFrameBetweenHops() throws {
    let box = LatestFrameBox()
    var frames: [DesktopFrame] = []
    for _ in 0..<3 {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 2, 2, kCVPixelFormatType_32BGRA, nil, &buffer)
        frames.append(DesktopFrame(try #require(buffer)))
    }
    #expect(box.offer(frames[0]))
    #expect(!box.offer(frames[1]))
    #expect(!box.offer(frames[2]))
    #expect(box.take() === frames[2])
    #expect(box.take() == nil)
    #expect(box.offer(frames[0]))
    box.clear()
    #expect(box.take() == nil)
    #expect(box.offer(frames[1]), "Clearing forgets the pending hop")
}

// L8: Veil's mask and shade are memoised on a bounded, quantised key.
@Test @MainActor func veilMemoisesMasksAndShadesWithinABound() {
    let renderer = NativeEffectRenderer(kind: .veil)
    renderer.prepare(size: CGSize(width: 320, height: 200), scale: 2)
    renderer.update(.init(closure: 0.3))
    #expect(renderer.memoisedShades == 1 && renderer.memoisedMasks == 1)
    renderer.update(.init(closure: 0.3001))
    #expect(renderer.memoisedShades == 1 && renderer.memoisedMasks == 1, "Nearby poses share an entry")
    for step in 0...200 { renderer.update(.init(closure: Double(step) / 200)) }
    #expect(renderer.memoisedMasks <= NativeEffectRenderer.memoLimit)
    #expect(renderer.memoisedShades <= NativeEffectRenderer.memoLimit)
    renderer.stop()
}
