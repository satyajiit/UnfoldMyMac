import Foundation
import Testing
@testable import UnfoldMyMacKit

/// Where the provider is showing, and whether it is moving — the two facts the app used to guess at.
private func reachDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("WallpaperProviderReachTests/\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test @MainActor func aProviderOnTheDesktopIsNotAProviderOnTheLockScreen() throws {
    // macOS keeps two selections per display — `Desktop`, and the `Idle` slot the lock screen and the
    // screen saver share. Counting surfaces cannot tell them apart, and reading a count as a lock screen
    // is how the app came to say "On your desktop and lock screen" over an exported still.
    let directory = try reachDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    let link = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })

    bridge.write(.init(templateID: "pulse", contextID: 7, surfaces: 1, roles: ["desktop"], framesPerSecond: 60, presentedFPS: 59.4))
    link.update(enabled: false, templateID: nil, source: nil)
    #expect(link.status == .live(templateID: "pulse", onLockScreen: false))
    #expect(link.status.lockScreenState == false, "A desktop surface answers the lock-screen question with no")

    bridge.write(.init(templateID: "pulse", contextID: 7, surfaces: 2, roles: ["desktop", "lockScreen"],
                       framesPerSecond: 60, presentedFPS: 59.4))
    link.update(enabled: false, templateID: nil, source: nil)
    #expect(link.status == .live(templateID: "pulse", onLockScreen: true))
    link.stop()
}

@Test @MainActor func theLockScreenIsRecognisedHoweverTheRoleIsSpelled() {
    // The role crosses a file between two processes that are updated separately, so a build skew must not
    // read as "not on the lock screen" — the silent wrong answer.
    for spelling in ["lockScreen", "LockScreen", "lockscreen"] {
        #expect(WallpaperProviderBridge.Heartbeat(roles: [spelling]).coversLockScreen, Comment(rawValue: spelling))
    }
    for spelling in ["desktop", "Desktop", ""] {
        #expect(!WallpaperProviderBridge.Heartbeat(roles: [spelling]).coversLockScreen, Comment(rawValue: spelling))
    }
    #expect(!WallpaperProviderBridge.Heartbeat(surfaces: 3).coversLockScreen,
            "Surfaces without a reported content type answer no, never yes")
}

@Test @MainActor func aHeartbeatFromAnEarlierBuildStillDecodes() throws {
    // The extension is replaced by the installer while its last heartbeat sits in the container. Swift's
    // synthesized decoder fails the whole value on one missing key, and a heartbeat that fails to decode
    // reads as no provider at all — which is the app taking back a screen the provider is still drawing.
    let directory = try reachDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    let legacy = #"{"version":1,"stampedAt":811146513.5,"templateID":"pulse","contextID":42,"surfaces":2}"#
    try Data(legacy.utf8).write(to: bridge.heartbeatURL)

    let beat = try #require(bridge.readHeartbeat(), "A payload missing every field added since must still decode")
    #expect(beat.surfaces == 2 && beat.templateID == "pulse" && beat.contextID == 42)
    #expect(beat.roles.isEmpty && beat.framesPerSecond == 0 && beat.presentedFPS == 0)
    #expect(!beat.coversLockScreen, "Nothing reported is not a lock screen")
}

@Test @MainActor func aSurfaceAskedForMotionAndPresentingNoneReadsAsStalledRatherThanLive() throws {
    // The failure that started all of this: the wallpaper is on screen and frozen. Everything that only
    // counts surfaces calls that a success, and the user sees a still image.
    let directory = try reachDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    let frozen = WallpaperProviderBridge.Heartbeat(templateID: "pulse", contextID: 7, surfaces: 1,
                                                   roles: ["desktop"], framesPerSecond: 60, presentedFPS: 0)

    // Freshly acquired: no statistics have landed yet, and calling that frozen would be a false alarm.
    let patient = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })
    bridge.write(frozen)
    patient.update(enabled: false, templateID: nil, source: nil)
    #expect(patient.status == .live(templateID: "pulse", onLockScreen: false), "A surface is given time to produce its first second")
    patient.stop()

    // The same heartbeat, once the grace window has passed.
    let impatient = WallpaperProviderLink(bridge: bridge, stallGrace: 0, systemSlots: { nil })
    impatient.update(enabled: false, templateID: nil, source: nil)
    #expect(impatient.status == .stalled(templateID: "pulse"))
    #expect(impatient.status.lockScreenState == false && !impatient.status.isLive)
    #expect(!impatient.status.allowsSystemWallpaperChanges, "A frozen surface is still the system's wallpaper")

    // A rate of 1 or 0 is a still scene by design — Reduce Motion, or a sleeping display.
    for asked in [0, 1] {
        bridge.write(.init(templateID: "pulse", contextID: 7, surfaces: 1, roles: ["desktop"],
                           framesPerSecond: asked, presentedFPS: 0))
        impatient.update(enabled: false, templateID: nil, source: nil)
        #expect(impatient.status == .live(templateID: "pulse", onLockScreen: false), Comment(rawValue: "asked for \(asked) fps"))
    }
    impatient.stop()
}

@Test @MainActor func theSurfaceRoleComesFromThePresentationModeBecauseNothingElseSaysIt() {
    // `WallpaperCreationRequestXPC` carries no content type. Dumped on macOS 26.6 it is exactly: size,
    // colourSpace, scaleFactor, directDisplayID, isPreview, presentationMode, systemAppearance,
    // debugBackgrounds, a cache directory and the choice payload. So the presentation mode is the only
    // thing that separates the desktop surface from the one the lock screen shows, and the host does set
    // it per surface — three acquires in the same millisecond carry `default`, `default` and `idle`.
    typealias Role = WallpaperProviderRequest.Role
    #expect(Role(presentationMode: "idle") == .lockScreen)
    #expect(Role(presentationMode: "locked") == .lockScreen)
    #expect(Role(presentationMode: "Locked") == .lockScreen)
    #expect(Role(presentationMode: "default") == .desktop)
    // Unknown and absent both mean desktop: claiming the lock screen wrongly is the failure being fixed.
    #expect(Role(presentationMode: "someFutureMode") == .desktop)
    #expect(Role(presentationMode: nil) == .desktop)
}

@Test @MainActor func theLockScreenStaysReportedBetweenOneLockAndTheNext() throws {
    // A lock-screen surface exists only while the lock screen is on screen. After unlocking, the heartbeat
    // has nothing to report — and "no surface right now" must not read as "not chosen for the lock
    // screen", which would send the user to change a setting they already made.
    let directory = try reachDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let bridge = WallpaperProviderBridge(directory: directory)
    bridge.write(.init(templateID: "pulse", contextID: 7, surfaces: 1, roles: ["desktop"],
                       framesPerSecond: 60, presentedFPS: 59.4))

    let chosen = WallpaperProviderLink(bridge: bridge, systemSlots: { true })
    chosen.update(enabled: false, templateID: nil, source: nil)
    #expect(chosen.status == .live(templateID: "pulse", onLockScreen: true))
    chosen.stop()

    let notChosen = WallpaperProviderLink(bridge: bridge, systemSlots: { false })
    notChosen.update(enabled: false, templateID: nil, source: nil)
    #expect(notChosen.status == .live(templateID: "pulse", onLockScreen: false))
    notChosen.stop()

    // A store this build cannot read leaves the live surfaces to answer, rather than asserting either way.
    let blind = WallpaperProviderLink(bridge: bridge, systemSlots: { nil })
    blind.update(enabled: false, templateID: nil, source: nil)
    #expect(blind.status == .live(templateID: "pulse", onLockScreen: false))
    bridge.write(.init(templateID: "pulse", contextID: 7, surfaces: 2, roles: ["desktop", "lockScreen"],
                       framesPerSecond: 60, presentedFPS: 59.4))
    blind.update(enabled: false, templateID: nil, source: nil)
    #expect(blind.status == .live(templateID: "pulse", onLockScreen: true), "A live lock-screen surface is proof on its own")
    blind.stop()
}
