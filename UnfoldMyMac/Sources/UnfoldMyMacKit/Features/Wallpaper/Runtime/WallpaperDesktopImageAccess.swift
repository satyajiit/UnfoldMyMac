import AppKit

@MainActor protocol WallpaperDesktopImageAccess {
    var screens: [WallpaperBackdropScreen] { get }
    func current(on screen: String) -> WallpaperDesktopImage?
    func set(_ image: WallpaperDesktopImage, on screen: String) throws
}
