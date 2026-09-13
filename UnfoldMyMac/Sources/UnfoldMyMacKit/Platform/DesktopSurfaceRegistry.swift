import AppKit
import Observation

/// The app's own desktop-level windows, so screen capture can exclude them without one feature
/// reaching into another. Posts one change notification per real change.
@MainActor @Observable final class DesktopSurfaceRegistry {
    private(set) var windowIDs: Set<CGWindowID> = []
    func update(_ ids: Set<CGWindowID>) {
        guard ids != windowIDs else { return }
        windowIDs = ids
        NotificationCenter.default.post(name: .desktopContentWindowsChanged, object: nil)
    }
}
