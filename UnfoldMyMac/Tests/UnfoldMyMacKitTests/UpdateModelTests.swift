import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func aCopyThatCannotUpdateItselfNeverAsksWhetherAnUpdateExists() async throws {
    let feed = FakeReleaseFeed(.success(makeRelease("1.0.2")))
    let model = makeUpdateModel(feed: feed, environment: FakeUpdateEnvironment(verdict: .blocked(.translocated)))
    model.start()
    defer { model.shutdown() }
    try await settle(until: { if case .unsupported = model.state { return true } else { return false } })
    model.checkNow(.manual)
    try await settle(until: { model.state == .unsupported(.translocated) })

    #expect(model.state == .unsupported(.translocated))
    #expect(model.state.badge == nil, "A blocked copy must not put a pill in the sidebar")
    #expect(!model.promptPending)
    #expect(feed.calls.withLock { $0 } == 0, "The kill switch has to stop the request, not just the interface")
}

@Test @MainActor func aBackgroundDiscoveryRaisesTheBadgeButWaitsForTheWindow() async throws {
    let model = makeUpdateModel(feed: FakeReleaseFeed(.success(makeRelease("1.0.2"))))
    model.checkNow(.automatic)
    try await settle(until: { model.state.badge != nil })

    #expect(model.state.badge == "Update")
    #expect(!model.promptPending, "A window must never be pulled forward at someone working elsewhere")
    model.windowDidBecomeVisible()
    #expect(model.promptPending, "Opening the window is when the sheet is welcome")
}

@Test @MainActor func remindMeLaterKeepsTheBadgeAndSkipRemovesTheVersionForGood() async throws {
    let store = InMemoryPreferencesStore()
    let model = makeUpdateModel(store: store, feed: FakeReleaseFeed(.success(makeRelease("1.0.2"))))
    model.checkNow(.manual)
    try await settle(until: { model.promptPending })

    model.remindLater()
    #expect(!model.promptPending)
    #expect(model.state.badge == "Update", "Later hides the sheet; the update is still waiting")

    model.skipThisVersion()
    #expect(model.state.badge == nil)
    #expect(store.load(UpdatePreferences.key).skippedVersion == "1.0.2")
}

@Test @MainActor func aSkippedVersionStaysHiddenUntilAskedForDirectly() async throws {
    let store = InMemoryPreferencesStore()
    var preferences = UpdatePreferences()
    preferences.skippedVersion = "1.0.2"
    store.save(preferences, for: UpdatePreferences.key)
    let feed = FakeReleaseFeed(.success(makeRelease("1.0.2")))
    let model = makeUpdateModel(store: store, feed: feed)

    model.checkNow(.automatic)
    try await settle(until: { feed.calls.withLock { $0 } == 1 && !model.state.isBusy })
    #expect(model.state.badge == nil)

    model.checkNow(.manual)
    try await settle(until: { feed.calls.withLock { $0 } == 2 && model.state.badge != nil })
    #expect(model.state.badge == "Update", "Checking by hand is the documented way back from a skip")
}

@Test @MainActor func aBackgroundFailureIsSilentWhileTheSameFailureAskedForIsShown() async throws {
    let feed = FakeReleaseFeed(.failure(.offline))
    let model = makeUpdateModel(feed: feed)

    model.checkNow(.automatic)
    try await settle(until: { feed.calls.withLock { $0 } == 1 && !model.state.isBusy })
    #expect(model.state == .idle, "Nothing about being offline is worth interrupting anyone over")
    #expect(model.state.badge == nil)

    model.checkNow(.manual)
    try await settle(until: { model.state == .failed(UpdateFailure(.offline, phase: .check)) })
    #expect(model.state == .failed(UpdateFailure(.offline, phase: .check)))
}

@Test @MainActor func anOlderReleaseIsNeverOfferedAsAnUpdate() async throws {
    let expected = UpdateState.upToDate(AppVersion("1.0.1")!, checkedAt: Date(timeIntervalSince1970: 1_800_000_000))
    let model = makeUpdateModel(current: "1.0.1", feed: FakeReleaseFeed(.success(makeRelease("1.0.0"))))
    model.checkNow(.manual)
    try await settle(until: { model.state == expected })
    #expect(model.state == expected, "A release older than the running one is not an update")
}

@Test @MainActor func turningOffAutomaticChecksIsRemembered() {
    let store = InMemoryPreferencesStore()
    let model = makeUpdateModel(store: store, feed: FakeReleaseFeed(.failure(.offline)))
    model.setAutomaticChecks(false)
    #expect(store.load(UpdatePreferences.key).automaticChecks == false)
}
