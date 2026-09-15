import ExtensionFoundation
import Foundation
import UnfoldMyMacKit

/// The wallpaper provider `.appex`, kept deliberately thin: the Kit owns the renderer, the XPC contract
/// and the data bridge, so the desktop and the lock screen run the same code as the app itself.
///
/// This target links with `-e _NSExtensionMain` (see `Package.swift`). Without that entry point the
/// process initialises, logs, and exits in a few milliseconds without ever accepting a connection — the
/// host then reports a bare `NSCocoaErrorDomain 4099` with nothing else to go on.
@main
final class UnfoldMyMacWallpaperExtension: NSObject, AppExtension {
    override required init() {
        super.init()
        UnfoldMyMacWallpaperProvider.start()
    }
    var configuration: some AppExtensionConfiguration { UnfoldMyMacWallpaperProvider.configuration() }
}
