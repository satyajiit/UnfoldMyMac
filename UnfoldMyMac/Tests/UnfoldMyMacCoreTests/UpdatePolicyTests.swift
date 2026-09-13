import Foundation
import Testing
@testable import UnfoldMyMacCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let current = AppVersion("1.0.1")!

private func release(_ version: String) -> UpdateRelease {
    let parsed = AppVersion(version)!
    return UpdateRelease(version: parsed, assetName: UpdateRelease.expectedAssetName(for: parsed),
                         assetURL: URL(string: "https://github.com/satyajiit/UnfoldMyMac/releases/download/v\(version)/x.dmg")!)
}

@Test func aBackgroundCheckThatFailsLeavesNoTraceInTheInterface() {
    let state = UpdatePolicy.next(after: .failure(.offline), trigger: .automatic,
                                  skipped: nil, current: current, now: now)
    #expect(state == .idle, "An unreachable network must never raise anything the user has to dismiss")
}

@Test func aCheckTheUserAskedForAlwaysAnswers() {
    let state = UpdatePolicy.next(after: .failure(.offline), trigger: .manual,
                                  skipped: nil, current: current, now: now)
    #expect(state == .failed(UpdateFailure(.offline, phase: .check)))
    let fine = UpdatePolicy.next(after: .none(current), trigger: .manual, skipped: nil, current: current, now: now)
    #expect(fine == .upToDate(current, checkedAt: now), "Clicking Check must say something, even when there is nothing")
}

@Test func beingUpToDateIsSilentInTheBackground() {
    #expect(UpdatePolicy.next(after: .none(current), trigger: .automatic, skipped: nil, current: current, now: now) == .idle)
}

@Test func downgradesAndRepeatsOfTheRunningVersionAreRefused() {
    for candidate in ["1.0.0", "1.0.1"] {
        let state = UpdatePolicy.next(after: .discovered(release(candidate)), trigger: .automatic,
                                      skipped: nil, current: current, now: now)
        #expect(state == .idle, "\(candidate) is not newer than \(current) and must never be offered")
    }
}

@Test func aSkippedVersionIsHiddenFromBackgroundChecksAndShownWhenAsked() {
    let skipped = AppVersion("1.0.2")!
    let quiet = UpdatePolicy.next(after: .discovered(release("1.0.2")), trigger: .automatic,
                                  skipped: skipped, current: current, now: now)
    #expect(quiet == .idle)
    let asked = UpdatePolicy.next(after: .discovered(release("1.0.2")), trigger: .manual,
                                  skipped: skipped, current: current, now: now)
    #expect(asked == .available(release("1.0.2")), "Checking by hand is the way back from a skip")
}

@Test func aVersionNewerThanTheSkippedOneIsStillOffered() {
    let state = UpdatePolicy.next(after: .discovered(release("1.1.0")), trigger: .automatic,
                                  skipped: AppVersion("1.0.2")!, current: current, now: now)
    #expect(state == .available(release("1.1.0")), "Skipping one version must not skip every later one")
}

@Test func theCheckCadenceBacksOffAfterAFailure() {
    var schedule = UpdatePolicy.schedule()
    schedule.succeeded(at: now)
    #expect(!schedule.isDue(at: now.addingTimeInterval(3600)))
    #expect(schedule.isDue(at: now.addingTimeInterval(UpdatePolicy.checkInterval + 1)))
    schedule.failed("offline", at: now)
    #expect(schedule.isDue(at: now.addingTimeInterval(UpdatePolicy.retryInterval + 1)),
            "A rate-limited launch must not cost six hours of blindness")
}

@Test func jitterStaysWithinBoundsAndNeverChecksMoreThanHourly() {
    #expect(UpdatePolicy.jittered(UpdatePolicy.checkInterval, random: { $0.lowerBound }) >= UpdatePolicy.floorInterval)
    #expect(UpdatePolicy.jittered(UpdatePolicy.checkInterval, random: { $0.upperBound })
            == UpdatePolicy.checkInterval + UpdatePolicy.jitter)
    #expect(UpdatePolicy.jittered(60, random: { _ in -3600 }) == UpdatePolicy.floorInterval)
}

@Test func theSheetWaitsForAWindowRatherThanPullingOneForward() {
    let candidate = release("1.0.2")
    #expect(UpdatePromptPolicy.decide(trigger: .automatic, windowVisible: false, lastSeen: nil, release: candidate)
            == .waitForWindow, "A menu-bar app must not steal focus to announce a download")
    #expect(UpdatePromptPolicy.decide(trigger: .automatic, windowVisible: true, lastSeen: nil, release: candidate) == .present)
    #expect(UpdatePromptPolicy.decide(trigger: .automatic, windowVisible: true, lastSeen: candidate.version, release: candidate)
            == .ignore, "Remind Me Later must not reopen on every window show")
    #expect(UpdatePromptPolicy.decide(trigger: .manual, windowVisible: true, lastSeen: candidate.version, release: candidate)
            == .present, "A click is answered even for a version already seen")
}
