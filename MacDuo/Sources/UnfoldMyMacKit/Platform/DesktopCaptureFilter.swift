import AppKit
import ScreenCaptureKit

extension Notification.Name {
    static let desktopContentWindowsChanged = Notification.Name("com.unfoldmymac.desktopContentWindowsChanged")
}

@MainActor enum DesktopCaptureFilter {
    static func make(content: SCShareableContent, displayID: CGDirectDisplayID, including requested: Set<CGWindowID>) throws -> SCContentFilter {
        guard CGDisplayIsBuiltin(displayID) != 0, let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureFailure.displayUnavailable
        }
        let process = ProcessInfo.processInfo.processIdentifier
        guard let ownApp = content.applications.first(where: { $0.processID == process }) else { throw CaptureFailure.exclusionUnavailable }
        let allowed = includedIDs(requested: requested,
            available: content.windows.map { ($0.windowID, $0.owningApplication?.processID ?? -1) }, process: process)
        return SCContentFilter(display: display, excludingApplications: [ownApp], exceptingWindows: content.windows.filter { allowed.contains($0.windowID) })
    }
    static func includedIDs(requested: Set<CGWindowID>, available: [(CGWindowID, pid_t)], process: pid_t) -> Set<CGWindowID> {
        Set(available.filter { $0.1 == process && requested.contains($0.0) }.map(\.0))
    }
}
