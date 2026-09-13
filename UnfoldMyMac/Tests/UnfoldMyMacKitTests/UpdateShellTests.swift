import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// A shell needs an effects model to exist; none of these tests exercise it.
@MainActor private func makeShellEffects() -> EffectsModel {
    let registry = makeRegistry()
    let session = EffectSession(registry: registry, host: FakeHost(), displays: FakeDisplay(), gpu: nil,
                                makeCapture: { FakeCapture() })
    return makeModel(store: InMemoryPreferencesStore(), registry: registry, session: session)
}

@MainActor private final class FakeUpdatePrompt: UpdatePrompting {
    var promptPending = false
    var windowShows = 0
    var dismissals = 0
    func windowDidBecomeVisible() { windowShows += 1 }
    func dismissPrompt() { dismissals += 1 }
}

@Test @MainActor func wallpaperSetupKeepsTheSheetWhenAnUpdateArrivesMidTask() {
    let prompt = FakeUpdatePrompt()
    prompt.promptPending = true
    let shell = AppShellModel(effects: makeShellEffects(), wallpaper: FakeWallpaperBrowsing(), updates: prompt)

    #expect(shell.sheet(wallpaperRequest: "abc") == .wallpaperSetup("abc"),
            "A discovery in the background must not replace a sheet the user is halfway through")
    #expect(shell.sheet(wallpaperRequest: nil) == .update)
    prompt.promptPending = false
    #expect(shell.sheet(wallpaperRequest: nil) == nil)
}

@Test @MainActor func dismissingASheetCancelsWhicheverOneWasShowing() {
    let prompt = FakeUpdatePrompt()
    let shell = AppShellModel(effects: makeShellEffects(), wallpaper: FakeWallpaperBrowsing(), updates: prompt)
    var wallpaperCancels = 0

    shell.dismissSheet(wallpaperRequest: "abc", cancelWallpaper: { wallpaperCancels += 1 })
    #expect(wallpaperCancels == 1)
    #expect(prompt.dismissals == 0)

    shell.dismissSheet(wallpaperRequest: nil, cancelWallpaper: { wallpaperCancels += 1 })
    #expect(wallpaperCancels == 1)
    #expect(prompt.dismissals == 1)
}

@Test @MainActor func theUpdatePromptIsToldWhenTheWindowAppears() {
    let prompt = FakeUpdatePrompt()
    let shell = AppShellModel(effects: makeShellEffects(), wallpaper: FakeWallpaperBrowsing(), updates: prompt)
    shell.windowDidShow()
    #expect(prompt.windowShows == 1, "The sheet waits for a window rather than pulling one forward")
}

@Test func theMenuBarSaysWhatIsWaitingRatherThanOfferingACheck() {
    var state = QuickMenuState(status: "Ready", effectEnabled: true, isPreviewing: false, selectedEffect: .frost,
                               wallpaperEnabled: false, effects: [], update: .idle)
    #expect(QuickMenuBuilder.menu(for: state).items.contains(.action("Check for Updates…", .checkForUpdates)))

    state.update = .available("1.0.2")
    #expect(QuickMenuBuilder.menu(for: state).items.contains(.action("Update to 1.0.2…", .installUpdate)))

    state.update = .ready("1.0.2")
    #expect(QuickMenuBuilder.menu(for: state).items.contains(.action("Relaunch to Finish 1.0.2…", .installUpdate)))

    // A copy that cannot update itself gets no row at all, rather than a permanently dimmed one.
    state.update = .unavailable
    let items = QuickMenuBuilder.menu(for: state).items
    #expect(!items.contains { if case .action(_, .checkForUpdates, _) = $0 { return true } else { return false } })
    #expect(!items.contains { if case .action(_, .installUpdate, _) = $0 { return true } else { return false } })
}

@Test func theUpdateRowSitsBetweenSettingsAndTheOpenSourceAsk() throws {
    let state = QuickMenuState(status: "Ready", effectEnabled: true, isPreviewing: false, selectedEffect: .frost,
                               wallpaperEnabled: false, effects: [], update: .available("1.0.2"))
    let items = QuickMenuBuilder.menu(for: state).items
    let settings = try #require(items.firstIndex(of: .action("Settings…", .showSettings)))
    let update = try #require(items.firstIndex(of: .action("Update to 1.0.2…", .installUpdate)))
    let star = try #require(items.firstIndex(of: .action("Star UnfoldMyMac on GitHub", .starRepository)))
    #expect(settings < update && update < star)
}
