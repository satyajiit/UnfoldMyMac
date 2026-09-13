import Foundation

/// Waits for a main-actor condition. GPU tests can hold the main actor for many seconds, so the deadline is generous
/// and queued main-actor work gets one more turn before the wait gives up.
@MainActor func settle(timeout: Duration = .seconds(30), until condition: @MainActor () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline { break }
        try await Task.sleep(for: .milliseconds(20))
    }
    var turns = 0
    while !condition() && turns < 10 { await Task.yield(); turns += 1 }
}
