import Testing
@testable import UnfoldMyMacKit

@Test @MainActor func theLockScreenCardNeverClaimsALockScreenItDoesNotHave() {
    // This card is the only place the app tells the user where their scene is actually being shown, and
    // the status behind it starts out unresolved on every launch. Saying "desktop only" while the answer
    // is still coming would be a plain untruth about a screen the user cannot see from here.
    typealias Copy = WallpaperLockScreenCard.Copy
    let both = Copy(status: .live(templateID: "pulse", onLockScreen: true), applied: true)
    #expect(both.title.localizedCaseInsensitiveContains("lock screen"))
    #expect(both.pane == nil, "The scene is already where it belongs; there is nothing to go and change")

    // The bug this pins: the provider rendering is not the same fact as the provider rendering on the
    // lock screen. macOS holds those as two selections, and the app read the first as the second for
    // long enough to promise a live lock screen that was showing an exported still the whole time.
    let desktopOnly = Copy(status: .live(templateID: "pulse", onLockScreen: false), applied: true)
    #expect(desktopOnly != both, "Live on the desktop must not read the same as live on the lock screen")
    #expect(desktopOnly.pane == .screenSaver, "The lock screen is the Idle slot, and that is the Screen Saver pane")
    #expect(desktopOnly.detail.localizedCaseInsensitiveContains("separate"),
            "The user is told why the lock screen did not follow, not just what to press")

    for applied in [true, false] {
        let checking = Copy(status: .unknown, applied: applied)
        #expect(checking.pane == nil, "Nothing is offered before the question is settled")
        #expect(!checking.title.localizedCaseInsensitiveContains("desktop"),
                "Not yet knowing must not be worded as knowing the answer is no")
        #expect(checking != Copy(status: .idle, applied: applied))

        let idle = Copy(status: .idle, applied: applied)
        #expect(idle.pane == .wallpaper && !idle.title.localizedCaseInsensitiveContains("lock screen"))
        #expect(idle.detail.contains("Dynamic Wallpapers"), "The way out is named, not implied")
    }

    let failed = Copy(status: .failed("remote CAContext unavailable"), applied: true)
    #expect(failed.pane != nil && failed.detail.contains("remote CAContext unavailable"),
            "A provider that could not render says why rather than going quiet")

    // A frozen surface is on screen, so it is neither a failure nor a success, and saying either hides
    // the one symptom the user can actually see.
    let stalled = Copy(status: .stalled(templateID: "pulse"), applied: true)
    #expect(stalled != both && stalled != failed)
    #expect(stalled.pane == nil, "There is nothing in System Settings that unfreezes a surface")
    #expect(stalled.title.localizedCaseInsensitiveContains("not moving"))
}
