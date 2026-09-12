import AppKit

private final class EffectPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor final class EffectHost: EffectHosting {
    // Above ordinary desktop windows, below system popup menus and security UI.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    private let panel = EffectPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    init() {
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.hasShadow = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = Self.level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }
    func install(_ view: NSView, on screen: NSScreen) {
        panel.setFrame(screen.frame, display: false)
        panel.contentView = view
    }
    var isVisible: Bool { panel.isVisible }
    func show() { if !panel.isVisible { panel.orderFrontRegardless() } }
    /// Called every frame the effect is clear; ordering out an already hidden panel would touch the window server each time.
    func hide() { if panel.isVisible { panel.orderOut(nil) } }
}
