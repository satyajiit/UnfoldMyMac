import QuartzCore
import UnfoldMyMacCore

/// Platform services built once per process and handed to each feature's composition root.
@MainActor struct AppDependencies {
    let preferences: any PreferencesStore
    let environment: any SystemEnvironmentObserving
    let displays: any DisplayProviding
    let surfaces: DesktopSurfaceRegistry
    let filePicker: any FilePicking
    let workspace: any WorkspaceOpening
    let capturePermission: any ScreenCapturePermissionChecking
    let clock: () -> TimeInterval

    static func live() -> AppDependencies {
        AppDependencies(preferences: UserDefaultsPreferencesStore(), environment: SystemEnvironment(), displays: DisplayEnvironment(),
                        surfaces: DesktopSurfaceRegistry(), filePicker: OpenPanelFilePicker(), workspace: SystemWorkspace(),
                        capturePermission: SystemScreenCapturePermission(), clock: { CACurrentMediaTime() })
    }
}
