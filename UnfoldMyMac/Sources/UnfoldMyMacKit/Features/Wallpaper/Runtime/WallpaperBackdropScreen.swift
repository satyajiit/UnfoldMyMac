import AppKit

/// One display, as the wallpaper feature needs to see it.
///
/// `name` and `isPrimary` exist so the app can both scope its work to one display and say which one in
/// the interface. `id` is the display's UUID string, which survives sleep, reconnection and reordering in
/// a way the `CGDirectDisplayID` beside it does not — and it is the identity the restoration journal has
/// always been keyed by, so the window path and the still path name the same screen the same way.
struct WallpaperBackdropScreen: Equatable, Identifiable {
    let id: String
    let size: CGSize
    var nativeSize: CGSize? = nil
    /// What the user calls this display: "Built-in Retina Display", "Odyssey G93SC".
    var name: String = ""
    /// The display carrying the menu bar. The app draws its own scene here and nowhere else.
    var isPrimary: Bool = false

    init(id: String, size: CGSize, nativeSize: CGSize? = nil, name: String = "", isPrimary: Bool = false) {
        self.id = id; self.size = size; self.nativeSize = nativeSize; self.name = name; self.isPrimary = isPrimary
    }
    @MainActor init(_ screen: NSScreen, primary: CGDirectDisplayID = CGMainDisplayID()) {
        self.init(id: Self.identity(of: screen), size: screen.frame.size,
                  nativeSize: screen.convertRectToBacking(screen.frame).size,
                  name: screen.localizedName, isPrimary: Self.displayID(of: screen) == primary)
    }
    @MainActor static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    @MainActor static func identity(of screen: NSScreen) -> String {
        let id = displayID(of: screen)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return String(id) }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
