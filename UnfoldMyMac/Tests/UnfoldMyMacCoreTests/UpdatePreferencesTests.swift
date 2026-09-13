import Foundation
import Testing
@testable import UnfoldMyMacCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Test func updatePreferencesKeepTheirPersistedNameAndHaveNothingToMigrate() {
    #expect(UpdatePreferences.key.name == "unfoldmymac.updates.v1")
    #expect(UpdatePreferences.key.legacyNames.isEmpty, "This key is new; there is no older payload to adopt")
    #expect(UpdatePreferences().automaticChecks, "Checking has to be on by default or nobody is ever told")
}

@Test func aPayloadSavedBeforeAFieldExistedStillLoads() throws {
    let data = Data(#"{"automaticChecks":false}"#.utf8)
    let decoded = try JSONDecoder().decode(UpdatePreferences.self, from: data)
    #expect(decoded.automaticChecks == false)
    #expect(decoded.skippedVersion == nil)
    #expect(try JSONDecoder().decode(UpdatePreferences.self, from: Data("{}".utf8)).automaticChecks)
}

@Test func preferencesRoundTripThroughTheirPrintedForm() throws {
    var value = UpdatePreferences()
    value.skippedVersion = "1.0.2"
    value.lastSeenVersion = "1.0.3"
    value.lastCheck = now
    let decoded = try JSONDecoder().decode(UpdatePreferences.self, from: JSONEncoder().encode(value))
    #expect(decoded == value)
    #expect(decoded.skipped == AppVersion("1.0.2"))
}

@Test func unreadableVersionsAndImpossibleDatesAreDiscardedOnLoad() {
    var value = UpdatePreferences()
    value.skippedVersion = "not a version"
    value.lastSeenVersion = "also not"
    value.lastCheck = now.addingTimeInterval(86_400)
    value.sanitize(now: now)
    #expect(value.skippedVersion == nil)
    #expect(value.lastSeenVersion == nil)
    #expect(value.lastCheck == nil, "A clock set into the future must not silence checks")

    var restored = UpdatePreferences()
    restored.lastCheck = now.addingTimeInterval(-400 * 24 * 3600)
    restored.sanitize(now: now)
    #expect(restored.lastCheck == nil, "A date restored from an old backup is not a real last check")
}
