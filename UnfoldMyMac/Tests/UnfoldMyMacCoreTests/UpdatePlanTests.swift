import Foundation
import Testing
@testable import UnfoldMyMacCore

private let current = AppVersion("1.0.1")!
private func candidate(_ version: String = "1.0.2", minimumSystem: String? = nil) -> UpdateRelease {
    let parsed = AppVersion(version)!
    return UpdateRelease(version: parsed, assetName: "x.dmg",
                         assetURL: URL(string: "https://github.com/x.dmg")!, minimumSystem: minimumSystem)
}
private func facts(eligibility: UpdateEligibility = .eligible, system: Int = 26,
                   install: Int64 = 10_000_000_000, download: Int64 = 10_000_000_000,
                   writable: Bool = true, owned: Bool = true) -> UpdateFacts {
    UpdateFacts(eligibility: eligibility, currentVersion: current, systemMajorVersion: system,
                freeSpaceAtInstall: install, freeSpaceAtDownload: download,
                installDirectoryWritable: writable, installedByCurrentUser: owned)
}

@Test func aHealthyMacProceeds() {
    #expect(UpdatePlan.decide(candidate(), facts: facts()) == .proceed)
}

@Test func aBlockedCopyNeverGetsAsFarAsSpendingBandwidth() {
    #expect(UpdatePlan.decide(candidate(), facts: facts(eligibility: .blocked(.translocated))) == .blocked(.translocated))
}

@Test func theDowngradeRefusalIsRepeatedImmediatelyBeforeTheDownload() {
    // An offer can outlive a manual upgrade, so discovery-time checks are not enough on their own.
    #expect(UpdatePlan.decide(candidate("1.0.0"), facts: facts()) == .alreadyCurrent)
    #expect(UpdatePlan.decide(candidate("1.0.1"), facts: facts()) == .alreadyCurrent)
}

@Test func anUpdateNeedingANewerSystemIsRefusedRatherThanInstalled() {
    // Installing this would leave someone with an app that will not launch and no way back.
    #expect(UpdatePlan.decide(candidate(minimumSystem: "27"), facts: facts(system: 26)) == .refuse(.needsNewerSystem("27")))
    #expect(UpdatePlan.decide(candidate(minimumSystem: "26"), facts: facts(system: 26)) == .proceed)
    #expect(UpdatePlan.decide(candidate(minimumSystem: nil), facts: facts(system: 26)) == .proceed,
            "An older release published no minimum, and that alone must not block it")
}

@Test func spaceAndPermissionAreCheckedBeforeTheDownloadRatherThanAfter() {
    #expect(UpdatePlan.decide(candidate(), facts: facts(owned: false)) == .refuse(.installedByAnotherUser))
    #expect(UpdatePlan.decide(candidate(), facts: facts(writable: false)) == .refuse(.installLocationNotWritable))
    #expect(UpdatePlan.decide(candidate(), facts: facts(download: 1000))
            == .refuse(.notEnoughSpaceToDownload(needed: UpdatePlan.downloadHeadroom)))
    #expect(UpdatePlan.decide(candidate(), facts: facts(install: 1000))
            == .refuse(.notEnoughSpaceToInstall(needed: UpdatePlan.installHeadroom)))
}

@Test func progressIsCoalescedButTheLastByteAlwaysArrives() {
    var gate = DownloadProgressGate()
    var published = 0
    let total: Int64 = 54_000_000
    for step in 0...10_000 {
        let received = Int64(step) * total / 10_000
        // Same instant every time, so only the fraction rule can let anything through.
        if gate.shouldPublish(received: received, total: total, at: 0) { published += 1 }
    }
    #expect(published <= 205, "A 54 MB transfer must not invalidate the interface thousands of times")
    #expect(published > 100, "It still has to move often enough to look alive")
    var last = DownloadProgressGate()
    _ = last.shouldPublish(received: 0, total: total, at: 0)
    let publishedFinalByte = last.shouldPublish(received: total, total: total, at: 0)
    #expect(publishedFinalByte, "A finished download must never sit at 99%")
}
