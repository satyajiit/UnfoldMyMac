import AppKit

/// Quitting once the detached installer is running.
///
/// `applicationShouldTerminateAfterLastWindowClosed` is false and the app lives in the menu bar, so
/// closing windows would not end the process. The installer is already waiting on this identifier.
@MainActor enum UpdateRelaunch {
    static func quit() { NSApp.terminate(nil) }
}
