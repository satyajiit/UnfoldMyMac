import UnfoldMyMacCore

enum QuickMenuBuilder {
    static func menu(for state: QuickMenuState) -> QuickMenu {
        var items: [QuickMenu.Item] = [.label(state.status), .separator]
        items.append(.action(state.effectEnabled ? "Turn Effect Off" : "Turn Effect On", .toggleEffect))
        for category in EffectCategory.allCases {
            let effects = state.effects.filter { $0.category == category }
            guard !effects.isEmpty else { continue }
            items.append(.submenu(category.title, effects.map { .action($0.title, .selectEffect($0.id), checked: $0.id == state.selectedEffect) }))
        }
        if state.isPreviewing { items.append(.action("Stop Preview", .stopPreview)) }
        items.append(.separator)
        items.append(.action("Wallpaper…", .showWallpaper))
        if state.wallpaperEnabled { items.append(.action("Stop Wallpaper", .stopWallpaper)) }
        items.append(.separator)
        items.append(.action("Open \(AppIdentity.name)…", .openApp))
        items.append(.action("Settings…", .showSettings))
        items.append(.separator)
        items.append(.action("Quit \(AppIdentity.name)", .quit))
        return QuickMenu(items: items)
    }
}
