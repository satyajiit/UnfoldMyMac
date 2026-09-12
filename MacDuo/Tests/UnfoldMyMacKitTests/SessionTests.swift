import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func nativeEffectsNeverCreateCaptureAndSwitchStopsFrost() async throws {
    let screen = try #require(NSScreen.screens.first)
    var captures: [FakeCapture] = []
    let registry = makeRegistry()
    let host = FakeHost()
    let session = EffectSession(registry: registry, host: host, displays: FakeDisplay(), gpu: nil, makeCapture: { let c = FakeCapture(); captures.append(c); return c })
    session.start(effect: .veil, screen: screen, reduceTransparency: false)
    session.update(.init(closure: 0.5))
    #expect(host.shown)
    session.start(effect: .fade, screen: screen, reduceTransparency: false)
    session.start(effect: .curtains, screen: screen, reduceTransparency: false)
    session.start(effect: .reverie, screen: screen, reduceTransparency: false)
    session.start(effect: .neonCoast, screen: screen, reduceTransparency: false)
    #expect(captures.isEmpty)
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    await Task.yield()
    #expect(captures.count == 1)
    #expect(captures[0].started)
    session.start(effect: .veil, screen: screen, reduceTransparency: false)
    await Task.yield()
    #expect(captures[0].stopped)
    #expect(captures[0].onFrame == nil)
    session.stop()
    #expect(!host.shown)
}
@Test @MainActor func staleCaptureCallbacksCannotAffectNewEffect() async throws {
    let screen = try #require(NSScreen.screens.first)
    let capture = FakeCapture()
    var renderers: [FakeRenderer] = []
    let session = EffectSession(registry: makeRegistry { _, r in renderers.append(r) }, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { capture })
    var failures = 0
    session.onError = { _ in failures += 1 }
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    let oldError = try #require(capture.onError)
    let oldFrame = try #require(capture.onFrame)
    session.start(effect: .fade, screen: screen, reduceTransparency: false)
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, 2, 2, kCVPixelFormatType_32BGRA, nil, &buffer)
    oldFrame(DesktopFrame(try #require(buffer)))
    oldError(CaptureFailure.exclusionUnavailable)
    #expect(failures == 0)
    #expect(renderers[0].received == 0)
    #expect(renderers[0].stopped)
    #expect(session.renderer != nil)
    session.stop()
}
@Test @MainActor func reducedTransparencyAvoidsCaptureAndZeroProgressHides() throws {
    let screen = try #require(NSScreen.screens.first)
    let host = FakeHost()
    var captures = 0
    var renderedID: EffectID?
    let registry = makeRegistry { id, _ in renderedID = id }
    let session = EffectSession(registry: registry, host: host, displays: FakeDisplay(), gpu: nil, makeCapture: { captures += 1; return FakeCapture() })
    session.start(effect: .frost, screen: screen, reduceTransparency: true)
    #expect(renderedID == .fade)
    #expect(captures == 0)
    session.start(effect: .curtains, screen: screen, reduceTransparency: true)
    session.start(effect: .reverie, screen: screen, reduceTransparency: true)
    session.start(effect: .neonCoast, screen: screen, reduceTransparency: true)
    #expect(renderedID == .fade)
    #expect(captures == 0)
    session.update(.init(closure: 0.5)); #expect(host.shown)
    session.update(.init(closure: 0.0001)); #expect(host.shown)
    session.update(.init(closure: 0)); #expect(!host.shown)
    session.stop()
}
@Test @MainActor func liveFramesUseFreshAngleWithoutDelayedEntryOrExit() throws {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore(), host = FakeHost()
    store.settings.effect = .curtains; store.settings.activation = 108
    sensor.angle = 110
    var renderer: FakeRenderer?
    let registry = makeRegistry { _, next in renderer = next }
    let session = EffectSession(registry: registry, host: host, displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var time = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session, clock: { time })
    defer { model.shutdown() }
    model.setEnabled(true)
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(!host.shown) // Enabling still observes display recovery.
    time = 0.6; model.tick()
    let active = try #require(renderer)
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(!host.shown)
    // No polling tick in between: the very next display frame reads the new angle.
    sensor.angle = 108
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(host.shown)
    #expect(active.lastContext?.closure == EffectMath.liveProgress(lid: 108, activation: 108, completionFraction: 0.8))
    sensor.angle = 90
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(active.lastContext?.closure == EffectMath.liveProgress(lid: 90, activation: 108, completionFraction: 0.8))
    sensor.angle = 109
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(!host.shown) // No filtered tail above the threshold.
    model.setActivation(109.2)
    #expect(model.settings.activation == 109)
    #expect(store.settings.activation == 109)
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(host.shown)
    sensor.angle = 5
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(!host.shown)
    #expect(session.renderer == nil)
    #expect(model.status == DisplaySafetyGate.State.closed.rawValue)
}

@Test @MainActor func previewScrubbingIsImmediateAndSensorLossStillStopsLiveRendering() throws {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore(), host = FakeHost()
    store.settings.effect = .fade
    var renderer: FakeRenderer?
    let registry = makeRegistry { _, next in renderer = next }
    let session = EffectSession(registry: registry, host: host, displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var time = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session, clock: { time })
    defer { model.shutdown() }
    model.beginPreview()
    time = 0.6; model.tick()
    model.scrubPreview(0.4); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(renderer?.lastContext?.closure == 0.5)
    model.scrubPreview(0.8); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(renderer?.lastContext?.closure == 1)
    model.scrubPreview(0); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(!host.shown)
    model.stopPreview()
    model.setEnabled(true)
    time = 1.2; model.tick()
    sensor.angle = nil; time = 2.3
    model.renderFrame(deltaTime: 1.0 / 60)
    #expect(session.renderer == nil)
    #expect(model.status == DisplaySafetyGate.State.noSensor.rawValue)
}
@Test @MainActor func previewRestoresStateAndDisplaySafetyWins() {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore()
    store.settings.effect = .fade
    let registry = makeRegistry()
    let host = FakeHost()
    let session = EffectSession(registry: registry, host: host, displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var time = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session, clock: { time })
    let shell = AppShellModel(effects: model, wallpaper: FakeWallpaperBrowsing())
    shell.route = .effects
    model.beginPreview(); #expect(model.enabled)
    time = 0.6; model.tick()
    #expect(session.renderer != nil)
    model.stopPreview(); #expect(!model.enabled); #expect(model.status == "Off")
    model.setEnabled(true)
    model.beginPreview(); model.stopPreview(); #expect(model.enabled)
    model.beginPreview(); shell.route = .settings; #expect(!model.isPreviewing)
    display.closed = true
    time = 1.5; model.tick()
    #expect(session.renderer == nil)
    #expect(model.status == DisplaySafetyGate.State.closed.rawValue)
    display.closed = false; display.screen = nil
    time = 2; model.tick()
    #expect(model.status == DisplaySafetyGate.State.noDisplay.rawValue)
    model.shutdown()
}
@Test @MainActor func cardPreviewsUseTheirOwnParametersAndKeepTheChosenEffect() throws {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore()
    store.settings.effect = .fade
    store.settings.parameters[EffectID.rise.rawValue] = .init(strength: 0.27, reveal: .straight)
    var renderedID: EffectID?
    var renderer: FakeRenderer?
    let registry = makeRegistry { id, next in renderedID = id; renderer = next }
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var now = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session, clock: { now })
    let shell = AppShellModel(effects: model, wallpaper: FakeWallpaperBrowsing())
    defer { model.shutdown() }
    model.libraryQuery = "My search"
    model.togglePreview(for: .rise)
    #expect(shell.route == .effects && model.isPreviewing && model.isPlaying)
    #expect(model.previewEffectID == .rise && model.activeEffect.id == .rise)
    #expect(model.settings.effect == .fade && store.settings.effect == .fade)
    #expect(model.libraryQuery == "My search")
    now = 0.6; model.tick(); model.scrubPreview(0.4); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(renderedID == .rise)
    #expect(renderer?.lastContext?.parameters == .init(strength: 0.27, reveal: .straight))
    #expect(model.status == "Previewing rise")
    // Switching previews retains the enabled state from before the first preview.
    model.togglePreview(for: .current)
    #expect(model.isPreviewing && model.isPlaying && model.previewEffectID == .current)
    #expect(model.settings.effect == .fade && store.settings.effect == .fade)
    model.togglePreview(for: .current)
    #expect(!model.isPreviewing && !model.enabled && !model.isPlaying)
    #expect(model.previewEffectID == nil && model.activeEffect.id == .fade)
    #expect(model.status == "Off")
    model.setEnabled(true)
    model.togglePreview(for: .rise); model.togglePreview(for: .curtains); model.stopPreview()
    #expect(model.enabled && model.activeEffect.id == .fade && store.settings.effect == .fade)
}

@Test @MainActor func selectingTheChosenCardOrLeavingEffectsEndsItsPreview() {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore()
    store.settings.effect = .fade
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session)
    let shell = AppShellModel(effects: model, wallpaper: FakeWallpaperBrowsing())
    defer { model.shutdown() }
    #expect(AppRoute.allCases == [.effects, .wallpaper, .settings])
    model.togglePreview(for: .rise)
    model.selectEffect(.fade)
    #expect(!model.isPreviewing && !model.enabled && model.previewEffectID == nil)
    #expect(model.settings.effect == .fade)
    model.togglePreview(for: .rise)
    shell.route = .settings
    #expect(!model.isPreviewing && !model.isPlaying && !model.enabled)
    #expect(model.settings.effect == .fade && store.settings.effect == .fade)
    model.togglePreview(for: .curtains)
    #expect(shell.route == .effects && model.isPreviewing)
    model.selectEffect(.rise)
    #expect(!model.isPreviewing && model.settings.effect == .rise && store.settings.effect == .rise)
}

@Test @MainActor func effectSettingsStopPreviewAndPreserveLibraryContext() {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore()
    store.settings.effect = .fade
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session)
    let shell = AppShellModel(effects: model, wallpaper: FakeWallpaperBrowsing())
    defer { model.shutdown() }
    model.libraryQuery = "Calm"
    model.libraryTag = "Minimal"
    model.togglePreview(for: .rise)
    shell.showEffectSettings()
    #expect(shell.route == .effects && shell.effectsPath == [.settings])
    #expect(!model.isPreviewing && !model.isPlaying && !model.enabled)
    #expect(model.previewEffectID == nil && model.settings.effect == .fade)
    model.setActivation(110)
    model.setCompletionFraction(0.8)
    shell.showEffectSettings()
    #expect(shell.effectsPath == [.settings])
    shell.effectsPath.removeLast() // Native Back returns to the library.
    #expect(model.libraryQuery == "Calm" && model.libraryTag == "Minimal")
    #expect(store.settings.activation == 110 && store.settings.completionFraction == 0.8)
    #expect(store.settings.effect == .fade)

    // Leaving the feature returns its next visit to the library. A new preview
    // restores the enabled state that preceded it.
    model.setEnabled(true)
    shell.showEffectSettings()
    shell.route = .settings
    #expect(shell.effectsPath.isEmpty)
    model.togglePreview(for: .curtains)
    #expect(shell.route == .effects && shell.effectsPath.isEmpty && model.isPreviewing)
    shell.showEffectSettings()
    #expect(!model.isPreviewing && model.enabled && model.activeEffect.id == .fade)
}

@Test @MainActor func captureStartupFailureStopsSession() async throws {
    let screen = try #require(NSScreen.screens.first)
    let capture = FakeCapture(); capture.failure = CaptureFailure.exclusionUnavailable
    let session = EffectSession(registry: makeRegistry(), host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { capture })
    var failures = 0; session.onError = { _ in failures += 1 }
    session.start(effect: .frost, screen: screen, reduceTransparency: false)
    for _ in 0..<10 { await Task.yield() }
    #expect(failures == 1)
    #expect(session.renderer == nil)
    #expect(capture.stopped)
}

@Test @MainActor func animatedEffectsUseTheSessionClockAndPauseWithPreview() throws {
    let display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore()
    store.settings.effect = .current
    var renderer: FakeRenderer?
    let registry = makeRegistry { _, next in renderer = next }
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var now = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session, clock: { now })
    defer { model.shutdown() }
    model.beginPreview(); now = 0.6; model.tick()
    model.scrubPreview(0.4); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(renderer?.lastContext?.time == 0)
    model.playPreview(); model.renderFrame(deltaTime: 1.0 / 60)
    let playing = try #require(renderer?.lastContext)
    #expect(playing.time > 0)
    model.pausePreview(); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(renderer?.lastContext == playing)
    model.selectEffect(.rise); model.beginPreview(); now = 1.2; model.tick()
    model.scrubPreview(0.4); model.playPreview(); model.renderFrame(deltaTime: 1.0 / 60)
    #expect(renderer?.lastContext?.time == 0) // Static effects keep their identical-pose cache.
}
