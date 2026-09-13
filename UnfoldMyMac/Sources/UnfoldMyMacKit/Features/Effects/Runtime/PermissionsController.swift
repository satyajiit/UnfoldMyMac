import Foundation
import Observation
import UnfoldMyMacCore

/// The last effect failure as the user sees it, and whether it is really the Screen Recording permission.
@MainActor @Observable final class PermissionsController {
    private(set) var errorMessage: String?
    private(set) var needsPermission = false
    @ObservationIgnored private let capturePermission: any ScreenCapturePermissionChecking
    @ObservationIgnored private let workspace: any WorkspaceOpening

    init(capturePermission: any ScreenCapturePermissionChecking, workspace: any WorkspaceOpening) {
        self.capturePermission = capturePermission; self.workspace = workspace
    }
    func clear() {
        if errorMessage != nil { errorMessage = nil }
        if needsPermission { needsPermission = false }
    }
    /// Records a failure; returns whether the fix is granting Screen Recording rather than anything in the app.
    @discardableResult func report(_ error: Error, requestedCapture: Bool) -> Bool {
        needsPermission = requestedCapture && !capturePermission.hasAccess
        errorMessage = needsPermission
            ? "Allow \(AppIdentity.name) in System Settings → Privacy & Security → Screen Recording, then enable Frost again."
            : error.localizedDescription
        return needsPermission
    }
    func openScreenRecordingSettings() { workspace.openScreenRecordingSettings() }
}
