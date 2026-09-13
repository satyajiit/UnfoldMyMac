import AppKit

@MainActor struct SystemWallpaperDesktopImages: WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] { NSScreen.screens.map { .init(id: identity($0), size: $0.frame.size, nativeSize: $0.convertRectToBacking($0.frame).size) } }
    func current(on screen: String) -> WallpaperDesktopImage? {
        guard let display = NSScreen.screens.first(where: { identity($0) == screen }),
              let url = NSWorkspace.shared.desktopImageURL(for: display) else { return nil }
        return .init(url: url, options: NSWorkspace.shared.desktopImageOptions(for: display) ?? [:])
    }
    func set(_ image: WallpaperDesktopImage, on screen: String) throws {
        guard let display = NSScreen.screens.first(where: { identity($0) == screen }) else { return }
        try NSWorkspace.shared.setDesktopImageURL(image.url, for: display, options: image.options)
    }
    private func identity(_ screen: NSScreen) -> String {
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return String(id) }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
