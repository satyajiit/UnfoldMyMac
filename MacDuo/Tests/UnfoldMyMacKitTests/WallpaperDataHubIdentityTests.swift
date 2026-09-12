import Foundation
import Synchronization
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private final class CountingProvider: WallpaperDataProvider {
    let id: String
    let fingerprint: String
    let interval: TimeInterval = 0.5
    let samples = Mutex(0)
    init(id: String, fingerprint: String) { self.id = id; self.fingerprint = fingerprint }
    func sample(at date: Date) async throws -> WallpaperDataSample {
        samples.withLock { $0 += 1 }
        return .init(timestamp: date, text: ["\(id).who": fingerprint])
    }
}

/// The hub publishes on the main actor, which other tests may hold for a while; wait for a condition instead of a fixed delay.
@MainActor private func settle(timeout: Duration = .seconds(10), until condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
}

// W7: a provider whose configuration changed is restarted; an identical one keeps running.
@Test @MainActor func dataHubRestartsOnlyProvidersWhoseConfigurationChanged() async throws {
    let hub = WallpaperDataHub()
    let alice = CountingProvider(id: "github", fingerprint: "alice")
    hub.update([alice])
    try await settle { hub.snapshot.text("github.who") == "alice" }
    #expect(hub.snapshot.text("github.who") == "alice")
    let sameConfiguration = CountingProvider(id: "github", fingerprint: "alice")
    hub.update([sameConfiguration])
    try await Task.sleep(for: .milliseconds(80))
    #expect(sameConfiguration.samples.withLock { $0 } == 0, "Same namespace and fingerprint: the running task is kept")
    let bob = CountingProvider(id: "github", fingerprint: "bob")
    hub.update([bob])
    try await settle { hub.snapshot.text("github.who") == "bob" }
    #expect(hub.snapshot.text("github.who") == "bob")
    let before = alice.samples.withLock { $0 }
    try await Task.sleep(for: .milliseconds(600))
    #expect(alice.samples.withLock { $0 } == before, "The replaced provider stopped sampling")
    hub.stop()
}
