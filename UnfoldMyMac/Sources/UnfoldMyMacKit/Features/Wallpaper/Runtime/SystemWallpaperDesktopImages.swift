import AppKit

@MainActor struct SystemWallpaperDesktopImages: WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] {
        let primary = CGMainDisplayID()
        return NSScreen.screens.map { .init($0, primary: primary) }
    }
    func current(on screen: String) -> WallpaperDesktopImage? {
        guard let display = NSScreen.screens.first(where: { WallpaperBackdropScreen.identity(of: $0) == screen }),
              let url = NSWorkspace.shared.desktopImageURL(for: display) else { return nil }
        return .init(url: url, options: NSWorkspace.shared.desktopImageOptions(for: display) ?? [:])
    }
    func set(_ image: WallpaperDesktopImage, on screen: String) throws {
        guard let display = NSScreen.screens.first(where: { WallpaperBackdropScreen.identity(of: $0) == screen }) else { return }
        try NSWorkspace.shared.setDesktopImageURL(image.url, for: display, options: image.options)
    }
}
