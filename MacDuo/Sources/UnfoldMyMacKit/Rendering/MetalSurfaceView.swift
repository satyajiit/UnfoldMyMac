import AppKit
import QuartzCore

/// A `CAMetalLayer`-backed view. It reports layout and occlusion; it never draws on its own.
@MainActor final class MetalSurfaceView: NSView {
    let surfaceLayer = CAMetalLayer()
    var onLayout: (() -> Void)?
    /// Called with `true` when any part of the window is visible, `false` when it is fully occluded.
    var onVisibilityChanged: ((Bool) -> Void)?
    private let surfaceIsOpaque: Bool
    private var occlusionObserver: NSObjectProtocol?

    init(opaque: Bool) {
        surfaceIsOpaque = opaque
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        autoresizingMask = [.width, .height]
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    isolated deinit { unobserveOcclusion() }

    override var isOpaque: Bool { surfaceIsOpaque }
    override func makeBackingLayer() -> CALayer { surfaceLayer }
    override func layout() { super.layout(); onLayout?() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); onLayout?() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        unobserveOcclusion()
        if let window {
            occlusionObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportVisibility() }
            }
        }
        onLayout?()
        reportVisibility()
    }
    private func reportVisibility() {
        onVisibilityChanged?(window?.occlusionState.contains(.visible) ?? false)
    }
    private func unobserveOcclusion() {
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
    }
}
