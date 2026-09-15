import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// The app's side of the bridge: what it sends the extension, what it concludes from the heartbeat, and
/// what it tells the user about where their scene is being shown.
private func providerDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("WallpaperProviderLinkTests/\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
/// Stands in for the app's live data hub.
@MainActor private final class StubSource: WallpaperSnapshotSource {
    var snapshot = WallpaperSnapshot()
    var liveInputs = WallpaperLiveInputs()
}

@Test @MainActor func bridgeCarriesLiveSamplesAndInputsIntoTheExtensionContainer() throws {
    let directory = try providerDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    var payload = WallpaperProviderBridge.Payload()
    payload.sources = ["claude": WallpaperDataSample(timestamp: .now, numbers: ["claude.tokens": 1234], text: ["claude.status": "Working"])]
    payload.errors = ["github": "Rate limited"]
    payload.inputs.lidOpen = 0.4
    payload.inputs.parallax = SIMD2(0.25, -0.5)
    payload.templateID = "pulse"
    payload.selectedAt = .now
    try bridge.write(payload)

    let read = try #require(bridge.readPayload())
    #expect(read == payload, "Every field the extension poses from survives the round trip")
    #expect(read.snapshot.number("claude.tokens") == 1234, "A fresh sample reads back through the snapshot")
    #expect(read.snapshot.text("github.repo") == nil, "An errored namespace stays unreadable")
    #expect(read.selectionIsCurrent(), "A selection just written is the one the extension should honour")
}

@Test @MainActor func aSelectionOlderThanTheFreshnessWindowYieldsToTheChoiceMacOSPersisted() throws {
    // With the app closed nothing rewrites the payload, and the scene must fall back to the wallpaper
    // macOS itself restored at login rather than to whatever the app last had selected.
    var payload = WallpaperProviderBridge.Payload()
    payload.templateID = "pulse"
    payload.selectedAt = Date.now.addingTimeInterval(-3600)
    #expect(!payload.selectionIsCurrent())
    payload.selectedAt = nil
    #expect(!payload.selectionIsCurrent())
}

@Test @MainActor func theAppStandsDownWhileTheProviderIsRenderingAndTakesTheScreenBackWhenItStops() throws {
    let directory = try providerDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    let link = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })
    let source = StubSource()

    link.update(enabled: true, templateID: "pulse", source: source)
    #expect(link.status == .unknown, "Nothing heard yet is not the same as nothing there")

    bridge.write(WallpaperProviderBridge.Heartbeat(templateID: "pulse", contextID: 42, surfaces: 1))
    link.update(enabled: true, templateID: "pulse", source: source)
    #expect(link.status == .live(templateID: "pulse", onLockScreen: false))
    #expect(link.status.isLive)

    // A heartbeat older than its lifetime is a provider that stopped, not one that is quiet.
    bridge.write(WallpaperProviderBridge.Heartbeat(
        stampedAt: Date.now.addingTimeInterval(-WallpaperProviderLink.heartbeatLifetime - 1), templateID: "pulse", contextID: 42, surfaces: 1))
    link.update(enabled: true, templateID: "pulse", source: source)
    #expect(link.status == .idle, "A stale heartbeat hands the screen back to the app")

    bridge.write(WallpaperProviderBridge.Heartbeat(templateID: nil, contextID: 0, surfaces: 0, failure: "remote CAContext unavailable"))
    link.update(enabled: true, templateID: "pulse", source: source)
    #expect(link.status == .failed("remote CAContext unavailable"), "A provider that could not render says so rather than going quiet")
    link.stop()
}

@Test @MainActor func aHeartbeatLeftOverFromAnEarlierLaunchIsNotAProviderThatStopped() throws {
    // The extension stamps its heartbeat only when the app speaks to it, and the file outlives the app.
    // At launch the stamp on disk is therefore almost always old, even though the provider has been
    // rendering since login. Reading that as "stopped" is what makes the app stop feeding it, which keeps
    // the stamp old — the silence would latch: the lock screen would fall back to dashes and the app would
    // believe the screen was free to overwrite.
    let directory = try providerDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    bridge.write(WallpaperProviderBridge.Heartbeat(stampedAt: Date.now.addingTimeInterval(-3600),
                                                  templateID: "pulse", contextID: 42, surfaces: 1))
    let link = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })

    // The app's own wallpaper is off, so it has nothing to send — which is precisely when it must still ask.
    link.update(enabled: false, templateID: nil, source: nil)
    #expect(link.status == .unknown, "An hours-old stamp is not an answer, it is a question nobody asked")
    #expect(!link.status.allowsSystemWallpaperChanges)

    // The extension answers, and the app now knows to feed a scene it never applied itself.
    bridge.write(WallpaperProviderBridge.Heartbeat(templateID: "pulse", contextID: 42, surfaces: 1))
    link.update(enabled: false, templateID: nil, source: nil)
    #expect(link.status == .live(templateID: "pulse", onLockScreen: false))
    link.stop()
}

@Test @MainActor func theAppLeavesTheSystemWallpaperAloneUntilItKnowsWhoOwnsIt() throws {
    // The one irreversible mistake here is replacing the user's wallpaper when their choice was our own
    // provider — that takes the lock screen with it. At launch nothing has been heard yet, so the app
    // must wait rather than assume the screen is free.
    let directory = try providerDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    let link = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })
    #expect(link.status == .unknown && !link.status.allowsSystemWallpaperChanges)

    link.update(enabled: true, templateID: "pulse", source: StubSource())
    #expect(link.status == .unknown, "A provider that has not answered yet is not a provider that is absent")
    #expect(!link.status.allowsSystemWallpaperChanges)

    bridge.write(WallpaperProviderBridge.Heartbeat(templateID: "pulse", contextID: 7, surfaces: 1))
    link.update(enabled: true, templateID: "pulse", source: StubSource())
    #expect(link.status.isLive && !link.status.allowsSystemWallpaperChanges,
            "macOS is showing our scene; writing a desktop image would throw that choice away")

    // Turning the app's wallpaper off must not blind it: it still has to know who owns the screen.
    link.update(enabled: false, templateID: nil, source: nil)
    #expect(link.status.isLive)
    link.stop()
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func theAppFeedsTheProviderEvenWithItsOwnWallpaperSwitchedOff() async throws {
    // The ordinary way in is to install the app and pick a scene in System Settings, never touching the
    // app's own wallpaper switch. Only this app can read ~/.claude for that scene, so the link has to run
    // from launch whatever the switch says — otherwise the lock screen fills with dashes, and the app,
    // having heard nothing, decides the system wallpaper is free to overwrite.
    let suite = "wallpaper-provider-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let directory = try providerDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let covers = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: covers) }
    let bridge = WallpaperProviderBridge(directory: directory)
    // macOS is already showing the provider when the app launches.
    bridge.write(WallpaperProviderBridge.Heartbeat(templateID: "pulse", contextID: 9, surfaces: 1))

    let model = WallpaperModel(preferences: UserDefaultsPreferencesStore(defaults: defaults), environment: FakeSystemEnvironment(),
                               displays: FakeDisplay(), surfaces: DesktopSurfaceRegistry(), gpu: try TestGPU.context(),
                               coverDirectory: covers, providerLink: WallpaperProviderLink(bridge: bridge, systemSlots: { nil }))
    model.start()
    #expect(!model.enabled, "The app's own wallpaper is off, which is exactly the case under test")
    await Task.yield()  // start() reconciles on the next hop so a launch is never held up by NSWorkspace.
    #expect(model.providerLink.status == .live(templateID: "pulse", onLockScreen: false))
    #expect(!model.desktop.isShowing, "macOS is compositing the scene; the app must not draw it a second time")
    let payload = try #require(bridge.readPayload(), "A provider the app never applied still has to be fed")
    #expect(payload.templateID == nil, "With the app's picker off, the scene is the one System Settings holds")
    model.shutdown()
}

@Test @MainActor func aPersistedAppPreferenceNeverOverrulesTheSceneChosenInSystemSettings() throws {
    // Two pickers can name a scene: the app's and macOS's. Only a change the user just made should win,
    // and simply launching the app with a saved preference is not such a change — treating it as one
    // would silently undo the wallpaper they had chosen moments earlier.
    let directory = try providerDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    let link = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })
    let source = StubSource()

    link.update(enabled: true, templateID: "pulse", source: source)
    let atLaunch = try #require(bridge.readPayload())
    #expect(atLaunch.templateID == "pulse")
    #expect(!atLaunch.selectionIsCurrent(), "A saved preference is not a decision the user just made")

    // The user picks a different scene in the app; that is a decision, and the live surface follows it.
    link.update(enabled: true, templateID: "hinge-garden", source: source)
    let afterPicking = try #require(bridge.readPayload())
    #expect(afterPicking.templateID == "hinge-garden" && afterPicking.selectionIsCurrent())

    // Repeating the same selection does not keep renewing the claim.
    let stamp = afterPicking.selectedAt
    link.update(enabled: true, templateID: "hinge-garden", source: source)
    #expect(try #require(bridge.readPayload()).selectedAt == stamp)
    link.stop()
}

@Test @MainActor func theBridgeWriteIntervalKeepsSamplesInsideTheirFreshnessWindow() {
    // A sample the extension considers stale degrades every metric the scene reads to nothing, so the
    // app must rewrite well before that. Two missed writes must still leave the sample readable.
    #expect(WallpaperProviderLink.writeInterval * 2 < WallpaperDataSample.freshness.upperBound)
    #expect(WallpaperProviderLink.heartbeatLifetime > WallpaperProviderLink.writeInterval * 2,
            "A single missed write must not look like a provider that stopped")
    #expect(WallpaperProviderLink.resolutionGrace > WallpaperProviderLink.writeInterval,
            "The grace period must outlast one write cycle, or the app decides before the provider answers")
}
