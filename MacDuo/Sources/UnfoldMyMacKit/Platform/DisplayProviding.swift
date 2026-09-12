import AppKit
import IOKit

@MainActor protocol DisplayProviding: AnyObject {
    func builtInScreen() -> NSScreen?
    func lidClosed(now: TimeInterval) -> Bool?
}
