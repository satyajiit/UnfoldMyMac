import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

// L4/W1: system sleep, screen sleep and an inactive login session are distinct facts.
@Test @MainActor func systemEnvironmentSeparatesSleepScreensAndSession() async throws {
    let workspaceCenter = NotificationCenter(), center = NotificationCenter()
    let environment = SystemEnvironment(workspaceCenter: workspaceCenter, center: center)
    environment.start(); defer { environment.stop() }
    #expect(!environment.state.displaysUnavailable)
    workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
    try await settle { environment.state.systemAsleep }
    #expect(environment.state.displaysUnavailable && !environment.state.screensAsleep)
    workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    try await settle { !environment.state.systemAsleep }
    workspaceCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
    try await settle { environment.state.screensAsleep }
    #expect(environment.state.displaysUnavailable)
    workspaceCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
    try await settle { !environment.state.screensAsleep }
    workspaceCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
    try await settle { environment.state.sessionInactive }
    #expect(!environment.state.displaysUnavailable, "Another user's session is not sleep")
    workspaceCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    try await settle { !environment.state.sessionInactive }
    let spaces = environment.state.spaceGeneration
    workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    try await settle { environment.state.spaceGeneration == spaces + 1 }
    #expect(environment.state.spaceGeneration == spaces + 1)
}

// P10: a display reconfiguration arrives as several notifications and must become one generation.
@Test @MainActor func displayChangesAreCoalescedIntoOneGeneration() async throws {
    let center = NotificationCenter()
    let environment = SystemEnvironment(workspaceCenter: NotificationCenter(), center: center)
    environment.start(); defer { environment.stop() }
    for _ in 0..<5 { center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil) }
    #expect(environment.state.displayGeneration == 0, "Nothing moves before the debounce elapses")
    try await settle { environment.state.displayGeneration == 1 }
    try await Task.sleep(for: SystemEnvironment.displayChangeDebounce * 3)
    #expect(environment.state.displayGeneration == 1)
    environment.stop()
    center.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    try await Task.sleep(for: SystemEnvironment.displayChangeDebounce * 2)
    #expect(environment.state.displayGeneration == 1, "A stopped environment observes nothing")
}

// The effects model consumes the shared state: sleep suspends it, a session switch does not, display changes rebuild.
@Test @MainActor func effectsPauseForSleepNotForSessionSwitchesAndRebuildOnDisplayChanges() async throws {
    let environment = FakeSystemEnvironment(), display = FakeDisplay(), sensor = FakeSensor(), store = InMemoryPreferencesStore()
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil, makeCapture: { FakeCapture() })
    var now = 0.0
    let model = makeModel(store: store, registry: registry, sensorFactory: { sensor }, displays: display, session: session, environment: environment, clock: { now })
    model.start(); defer { model.shutdown() }
    model.setEnabled(true); now = 0.6; model.tick()
    #expect(session.renderer != nil)
    environment.state.sessionInactive = true
    for _ in 0..<20 { await Task.yield() }
    #expect(session.renderer != nil && model.status != "Paused · sleeping")
    environment.state.systemAsleep = true
    try await settle { model.status == "Paused · sleeping" }
    #expect(model.status == "Paused · sleeping" && session.renderer == nil)
    environment.state.systemAsleep = false
    try await settle { now += 0.6; model.tick(); return session.renderer != nil }
    #expect(session.renderer != nil)
    environment.state.displayGeneration += 1
    try await settle { session.renderer == nil }
    #expect(session.renderer == nil, "A display change tears the session down until the gate is ready again")
    try await settle { now += 0.6; model.tick(); return session.renderer != nil }
    #expect(session.renderer != nil)
}
