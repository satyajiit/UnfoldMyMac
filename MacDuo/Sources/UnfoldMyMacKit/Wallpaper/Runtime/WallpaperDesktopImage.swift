import AppKit

struct WallpaperDesktopImage: Codable, Equatable {
    var url: URL
    var scaling: Int?
    var clipping: Bool?
    var fill: [Double]?

    @MainActor init(url: URL, options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]) {
        self.url = url
        scaling = (options[.imageScaling] as? NSNumber)?.intValue
        clipping = (options[.allowClipping] as? NSNumber)?.boolValue
        if let color = (options[.fillColor] as? NSColor)?.usingColorSpace(.deviceRGB) {
            fill = [color.redComponent, color.greenComponent, color.blueComponent]
        }
    }
    @MainActor var options: [NSWorkspace.DesktopImageOptionKey: Any] {
        var values: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        if let scaling { values[.imageScaling] = scaling }
        if let clipping { values[.allowClipping] = clipping }
        if let fill, fill.count == 3 { values[.fillColor] = NSColor(red: fill[0], green: fill[1], blue: fill[2], alpha: 1) }
        return values
    }
}

struct WallpaperBackdropScreen {
    let id: String
    let size: CGSize
}

@MainActor protocol WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] { get }
    func current(on screen: String) -> WallpaperDesktopImage?
    func set(_ image: WallpaperDesktopImage, on screen: String) throws
}

@MainActor struct SystemWallpaperDesktopImages: WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] { NSScreen.screens.map { .init(id: identity($0), size: $0.frame.size) } }
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
