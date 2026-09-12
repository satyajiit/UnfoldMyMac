import AppKit
import Observation

/// One set of workspace, power and display observers for the whole process. Display changes arrive
/// several times per reconfiguration, so they are coalesced before `displayGeneration` moves.
@MainActor @Observable final class SystemEnvironment: SystemEnvironmentObserving {
    static let displayChangeDebounce: Duration = .milliseconds(150)
    private(set) var state = SystemState()
    @ObservationIgnored private let workspace: NSWorkspace
    @ObservationIgnored private let workspaceCenter: NotificationCenter
    @ObservationIgnored private let center: NotificationCenter
    @ObservationIgnored private let processInfo: ProcessInfo
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var displayChange: Task<Void, Never>?

    init(workspace: NSWorkspace = .shared, workspaceCenter: NotificationCenter? = nil, center: NotificationCenter = .default,
         processInfo: ProcessInfo = .processInfo) {
        self.workspace = workspace; self.workspaceCenter = workspaceCenter ?? workspace.notificationCenter
        self.center = center; self.processInfo = processInfo
    }
    func start() {
        guard observers.isEmpty else { return }
        refreshAccessibility(); refreshPower()
        observe(NSWorkspace.willSleepNotification, in: workspaceCenter) { $0.mutate { $0.systemAsleep = true } }
        observe(NSWorkspace.didWakeNotification, in: workspaceCenter) { $0.mutate { $0.systemAsleep = false } }
        observe(NSWorkspace.screensDidSleepNotification, in: workspaceCenter) { $0.mutate { $0.screensAsleep = true } }
        observe(NSWorkspace.screensDidWakeNotification, in: workspaceCenter) { $0.mutate { $0.screensAsleep = false } }
        observe(NSWorkspace.sessionDidResignActiveNotification, in: workspaceCenter) { $0.mutate { $0.sessionInactive = true } }
        observe(NSWorkspace.sessionDidBecomeActiveNotification, in: workspaceCenter) { $0.mutate { $0.sessionInactive = false } }
        observe(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, in: workspaceCenter) { $0.refreshAccessibility() }
        observe(NSWorkspace.activeSpaceDidChangeNotification, in: workspaceCenter) { $0.mutate { $0.spaceGeneration += 1 } }
        observe(.NSProcessInfoPowerStateDidChange, in: center) { $0.refreshPower() }
        observe(ProcessInfo.thermalStateDidChangeNotification, in: center) { $0.refreshPower() }
        observe(NSApplication.didChangeScreenParametersNotification, in: center) { $0.scheduleDisplayChange() }
    }
    func stop() {
        observers.forEach { $0.0.removeObserver($0.1) }; observers.removeAll()
        displayChange?.cancel(); displayChange = nil
    }
    isolated deinit { stop() }

    private func refreshAccessibility() {
        let motion = workspace.accessibilityDisplayShouldReduceMotion, transparency = workspace.accessibilityDisplayShouldReduceTransparency
        mutate { $0.reduceMotion = motion; $0.reduceTransparency = transparency }
    }
    private func refreshPower() {
        let lowPower = processInfo.isLowPowerModeEnabled
        let thermal = processInfo.thermalState == .serious || processInfo.thermalState == .critical
        mutate { $0.lowPower = lowPower; $0.thermallyLimited = thermal }
    }
    private func scheduleDisplayChange() {
        displayChange?.cancel()
        displayChange = Task { [weak self] in
            try? await Task.sleep(for: Self.displayChangeDebounce)
            guard !Task.isCancelled else { return }
            self?.mutate { $0.displayGeneration += 1 }
        }
    }
    /// Observers fire for repeated identical facts; only a real change is published.
    private func mutate(_ change: (inout SystemState) -> Void) {
        var next = state; change(&next)
        if next != state { state = next }
    }
    private func observe(_ name: Notification.Name, in center: NotificationCenter, action: @escaping @MainActor (SystemEnvironment) -> Void) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        observers.append((center, observer))
    }
}
