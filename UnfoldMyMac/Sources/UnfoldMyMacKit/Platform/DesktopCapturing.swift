import AppKit
import UnfoldMyMacCore
import CoreMedia
import ScreenCaptureKit

@MainActor protocol DesktopCapturing: AnyObject {
    var onFrame: ((DesktopFrame) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func start(displayID: CGDirectDisplayID) async throws
    func stop() async
}
