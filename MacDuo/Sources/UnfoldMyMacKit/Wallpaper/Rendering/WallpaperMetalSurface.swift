import AppKit
import QuartzCore

/// A layer-backed surface; no MetalKit timer or synchronous nextDrawable acquisition.
@MainActor final class WallpaperMetalSurface: NSView {
    var onLayout: (() -> Void)?
    override var isOpaque: Bool { true }
    override func makeBackingLayer() -> CALayer { CAMetalLayer() }
    override func layout() { super.layout(); onLayout?() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); onLayout?() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); onLayout?() }
}
