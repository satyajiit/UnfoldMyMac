import AppKit

/// The runtime owns these observers; no template installs timers or lifecycle handlers.
@MainActor final class WallpaperEnvironment {
    var onChange: (() -> Void)?
    var onDisplaysChanged: (() -> Void)?
    var onSpaceChanged: (() -> Void)?
    private(set) var sleeping = false
    private var sessionInactive = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var activity: NSObjectProtocol?
    var suspended: Bool { sleeping || sessionInactive }
    var reducedMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var lowPower: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
    var thermal: Bool { ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical }
    func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(NSWorkspace.screensDidSleepNotification, in: workspace) { $0.sleeping = true }
        observe(NSWorkspace.screensDidWakeNotification, in: workspace) { $0.sleeping = false }
        observe(NSWorkspace.willSleepNotification, in: workspace) { $0.sleeping = true }
        observe(NSWorkspace.didWakeNotification, in: workspace) { $0.sleeping = false }
        observe(NSWorkspace.sessionDidResignActiveNotification, in: workspace) { $0.sessionInactive = true }
        observe(NSWorkspace.sessionDidBecomeActiveNotification, in: workspace) { $0.sessionInactive = false }
        observe(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, in: workspace) { _ in }
        observe(NSWorkspace.activeSpaceDidChangeNotification, in: workspace) { $0.onSpaceChanged?() }
        observe(.NSProcessInfoPowerStateDidChange, in: .default) { _ in }
        observe(ProcessInfo.thermalStateDidChangeNotification, in: .default) { _ in }
        observe(NSApplication.didChangeScreenParametersNotification, in: .default) { $0.onDisplaysChanged?() }
    }
    func stop() {
        observers.forEach { $0.0.removeObserver($0.1) }; observers.removeAll()
        setRendering(false)
    }
    func setRendering(_ enabled: Bool) {
        if enabled && activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "Rendering the live desktop wallpaper")
        } else if !enabled, let activity {
            ProcessInfo.processInfo.endActivity(activity); self.activity = nil
        }
    }
    private func observe(_ name: Notification.Name, in center: NotificationCenter, action: @escaping @MainActor (WallpaperEnvironment) -> Void) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; action(self); self.onChange?()
            }
        }
        observers.append((center, observer))
    }
}
