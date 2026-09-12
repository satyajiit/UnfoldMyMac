import Foundation
import UnfoldMyMacCore

/// Everything the effects model needs, built once by the feature's composition root.
@MainActor struct EffectsDependencies {
    let preferences: any PreferencesStore
    let registry: EffectRegistry
    let makeSensor: () -> any LidReading
    let displays: any DisplayProviding
    let session: EffectSession
    let environment: any SystemEnvironmentObserving
    let filePicker: any FilePicking
    let workspace: any WorkspaceOpening
    let capturePermission: any ScreenCapturePermissionChecking
    let artworkLibrary: ArtworkLibrary?
    let clock: () -> TimeInterval
}
