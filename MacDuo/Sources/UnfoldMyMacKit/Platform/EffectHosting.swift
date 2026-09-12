import AppKit

@MainActor protocol EffectHosting: AnyObject {
    func install(_ view: NSView, on screen: NSScreen)
    func show()
    func hide()
}
