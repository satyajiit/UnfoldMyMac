/// The wallpaper feature renders its preview only while the user is looking at it.
@MainActor protocol WallpaperBrowsing: AnyObject {
    func setBrowsing(_ value: Bool)
}

extension WallpaperModel: WallpaperBrowsing {}
