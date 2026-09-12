import CoreGraphics

@MainActor protocol ScreenCapturePermissionChecking: AnyObject {
    var hasAccess: Bool { get }
}

@MainActor final class SystemScreenCapturePermission: ScreenCapturePermissionChecking {
    var hasAccess: Bool { CGPreflightScreenCaptureAccess() }
}
