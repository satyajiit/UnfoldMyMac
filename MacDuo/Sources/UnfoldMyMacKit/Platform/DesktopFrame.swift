import AppKit
import UnfoldMyMacCore
import CoreMedia
import ScreenCaptureKit

/// Retains an immutable capture buffer while transferring it to the main actor/GPU.
final class DesktopFrame: @unchecked Sendable {
    let buffer: CVPixelBuffer
    init(_ buffer: CVPixelBuffer) { self.buffer = buffer }
}
