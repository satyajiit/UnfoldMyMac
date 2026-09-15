import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func quickMenuReflectsEffectPreviewAndWallpaperState() throws {
    let effects = EffectRegistry.builtIn().descriptors
    let category = effects[0].category
    let subset = effects.filter { $0.category == category }
    var state = QuickMenuState(status: "Ready", effectEnabled: false, isPreviewing: false, selectedEffect: subset[0].id, wallpaperEnabled: false, effects: subset)
    let menu = QuickMenuBuilder.menu(for: state)
    #expect(menu.items.first == .label("Ready"))
    #expect(menu.items.contains(.action("Turn Effect On", .toggleEffect)))
    let submenus = menu.items.compactMap { item -> (String, [QuickMenu.Item])? in
        if case .submenu(let title, let children) = item { return (title, children) } else { return nil }
    }
    #expect(submenus.count == 1 && submenus.first?.0 == category.title, "Categories without effects are not listed")
    #expect(submenus.first?.1 == subset.map { .action($0.title, .selectEffect($0.id), checked: $0.id == subset[0].id) })
    #expect(!menu.items.contains(.action("Stop Preview", .stopPreview)) && !menu.items.contains(.action("Stop Wallpaper", .stopWallpaper)))
    #expect(menu.items.contains(.action("Wallpaper…", .showWallpaper)) && menu.items.contains(.action("Settings…", .showSettings)))
    // The open-source ask sits between Settings and Quit, so it is visible without being the
    // thing your cursor lands on when you reach for Quit.
    let star = QuickMenu.Item.action("Star \(AppIdentity.name) on GitHub", .starRepository)
    let starIndex = try #require(menu.items.firstIndex(of: star))
    let settingsIndex = try #require(menu.items.firstIndex(of: .action("Settings…", .showSettings)))
    let quitIndex = try #require(menu.items.firstIndex(of: .action("Quit \(AppIdentity.name)", .quit)))
    #expect(settingsIndex < starIndex && starIndex < quitIndex)
    #expect(menu.items.last == .action("Quit \(AppIdentity.name)", .quit))
    state.effectEnabled = true; state.isPreviewing = true; state.wallpaperEnabled = true
    let live = QuickMenuBuilder.menu(for: state)
    #expect(live.items.contains(.action("Turn Effect Off", .toggleEffect)))
    #expect(live.items.contains(.action("Stop Preview", .stopPreview)) && live.items.contains(.action("Stop Wallpaper", .stopWallpaper)))
}

@Test @MainActor func theMenuOffersTheLockScreenOnlyWhenThereIsAProviderToOfferIt() {
    let effects = EffectRegistry.builtIn().descriptors
    var state = QuickMenuState(status: "Ready", effectEnabled: false, isPreviewing: false,
                               selectedEffect: effects[0].id, wallpaperEnabled: false, effects: [effects[0]])
    // The Screen Saver pane, not Wallpaper: the lock screen is the system's `Idle` slot, and sending the
    // user to the pane they have already used is the shape of the bug this row was added to fix.
    let add = QuickMenu.Item.action("Add to Lock Screen…", .openLockScreenSettings)
    let on = QuickMenu.Item.label("On desktop & lock screen")

    // A build without the appex must not promise something it cannot do.
    let without = QuickMenuBuilder.menu(for: state)
    #expect(!without.items.contains(add) && !without.items.contains(on))

    // Installed, but the provider has not answered yet: neither line is true, so neither is shown.
    state.wallpaperProviderInstalled = true
    let checking = QuickMenuBuilder.menu(for: state)
    #expect(!checking.items.contains(add) && !checking.items.contains(on))

    state.wallpaperOnLockScreen = false
    let offered = QuickMenuBuilder.menu(for: state)
    #expect(offered.items.contains(add) && !offered.items.contains(on))

    // Already on the lock screen: say so rather than offering to do it again.
    state.wallpaperOnLockScreen = true
    let live = QuickMenuBuilder.menu(for: state)
    #expect(live.items.contains(on) && !live.items.contains(add))
}
