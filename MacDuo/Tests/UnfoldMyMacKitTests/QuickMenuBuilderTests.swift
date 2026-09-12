import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func quickMenuReflectsEffectPreviewAndWallpaperState() {
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
    #expect(menu.items.last == .action("Quit \(AppIdentity.name)", .quit))
    state.effectEnabled = true; state.isPreviewing = true; state.wallpaperEnabled = true
    let live = QuickMenuBuilder.menu(for: state)
    #expect(live.items.contains(.action("Turn Effect Off", .toggleEffect)))
    #expect(live.items.contains(.action("Stop Preview", .stopPreview)) && live.items.contains(.action("Stop Wallpaper", .stopWallpaper)))
}
