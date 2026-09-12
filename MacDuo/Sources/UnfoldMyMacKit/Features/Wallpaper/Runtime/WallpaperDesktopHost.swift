import AppKit
import SwiftUI

@MainActor final class WallpaperDesktopHost {
    private(set) var windows: [NSWindow] = []
    private let surfaces: DesktopSurfaceRegistry
    init(surfaces: DesktopSurfaceRegistry) { self.surfaces = surfaces }
    func show<Content: View>(@ViewBuilder content: () -> Content) {
        close()
        for screen in NSScreen.screens {
            let window = DesktopWallpaperWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            window.setFrame(screen.frame, display: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            window.title = "UnfoldMyMac Wallpaper"
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.isOpaque = true; window.backgroundColor = .black
            window.hasShadow = false; window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false; window.isExcludedFromWindowsMenu = true
            let hosting = NSHostingView(rootView: content().ignoresSafeArea())
            hosting.safeAreaRegions = []
            hosting.sizingOptions = []
            window.contentView = hosting
            window.setFrame(screen.frame, display: true)
            window.orderBack(nil)
            windows.append(window)
        }
        surfaces.update(Set(windows.compactMap { CGWindowID(exactly: $0.windowNumber) }))
    }
    func stop() { close(); surfaces.update([]) }
    private func close() {
        for window in windows { window.orderOut(nil); window.contentView = nil; window.close() }
        windows.removeAll()
    }
}

private final class DesktopWallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
