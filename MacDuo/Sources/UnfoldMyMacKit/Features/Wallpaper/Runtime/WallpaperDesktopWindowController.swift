import AppKit
import SwiftUI
import UnfoldMyMacCore

/// One desktop-level window on one screen: an AppKit Metal surface under a hosting view for the text layers.
/// The controller owns the renderer, so its display link is invalidated the moment the window closes (P2).
@MainActor final class WallpaperDesktopWindowController {
    let displayID: CGDirectDisplayID
    private(set) var window: NSWindow?
    private let renderer: WallpaperSurfaceRenderer

    init(screen: NSScreen, displayID: CGDirectDisplayID, pipeline: WallpaperPipeline, surface: WallpaperSurfaceModel) {
        self.displayID = displayID
        renderer = WallpaperSurfaceRenderer(pipeline: pipeline)
        renderer.onStats = { [weak surface] stats in surface?.record(stats, for: displayID) }
        let window = DesktopWallpaperWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        window.setFrame(screen.frame, display: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        window.title = "\(AppIdentity.name) Wallpaper"
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = true; window.backgroundColor = .black
        window.hasShadow = false; window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false; window.isExcludedFromWindowsMenu = true
        let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        let surfaceView = renderer.surfaceView
        surfaceView.frame = content.bounds; surfaceView.autoresizingMask = [.width, .height]
        content.addSubview(surfaceView)
        let layers = NSHostingView(rootView: WallpaperLayersRoot(surface: surface))
        layers.safeAreaRegions = []; layers.sizingOptions = []
        layers.frame = content.bounds; layers.autoresizingMask = [.width, .height]
        content.addSubview(layers)
        window.contentView = content
        window.setFrame(screen.frame, display: true)
        window.orderBack(nil)
        self.window = window
    }
    func apply(_ pose: WallpaperPose, framesPerSecond: Int) {
        renderer.configure(pose, framesPerSecond: framesPerSecond)
    }
    func close() {
        renderer.stop()
        guard let window else { return }
        window.orderOut(nil); window.contentView = nil; window.close()
        self.window = nil
    }
    isolated deinit { close() }
}

private final class DesktopWallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
