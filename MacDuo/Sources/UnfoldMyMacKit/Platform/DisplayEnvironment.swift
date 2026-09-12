import AppKit
import IOKit

@MainActor final class DisplayEnvironment: DisplayProviding {
    func builtInScreen() -> NSScreen? { Self.usableBuiltInScreen() }
    private let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    private var lastPoll: TimeInterval = -.infinity
    private var closed: Bool?

    func lidClosed(now: TimeInterval) -> Bool? {
        if now - lastPoll >= 0.1 {
            lastPoll = now
            if root != 0 {
                closed = IORegistryEntryCreateCFProperty(
                    root,
                    "AppleClamshellState" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? Bool
            }
        }
        return closed
    }

    static func usableBuiltInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(id) != 0
                && CGDisplayIsOnline(id) != 0
                && CGDisplayIsActive(id) != 0
                && CGDisplayIsAsleep(id) == 0
                && CGDisplayIsInMirrorSet(id) == 0
        }
    }

    deinit {
        if root != 0 { IOObjectRelease(root) }
    }
}
