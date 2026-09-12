import AppKit
import IOKit

@MainActor protocol DisplayProviding: AnyObject {
    func builtInScreen() -> NSScreen?
    func lidClosed(now: TimeInterval) -> Bool?
    func displayID(of screen: NSScreen) -> CGDirectDisplayID?
}

extension DisplayProviding {
    func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
