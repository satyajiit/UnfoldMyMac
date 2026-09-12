import Foundation

/// Holds a user-initiated activity while the desktop wallpaper animates so the system does not
/// throttle timers; idle system sleep stays allowed.
@MainActor final class RenderingActivity {
    private var activity: NSObjectProtocol?
    func setRendering(_ enabled: Bool) {
        if enabled && activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "Rendering the live desktop wallpaper")
        } else if !enabled, let activity {
            ProcessInfo.processInfo.endActivity(activity); self.activity = nil
        }
    }
    isolated deinit { setRendering(false) }
}
