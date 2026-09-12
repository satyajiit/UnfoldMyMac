import AppKit
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor final class FakeHost: EffectHosting {
    var shown = false
    func install(_ view: NSView, on screen: NSScreen) {}
    func show() { shown = true }
    func hide() { shown = false }
}
@MainActor final class FakeRenderer: DesktopFrameConsuming {
    let view = NSView()
    var ready = true
    var animatesWithTime = false
    var received = 0
    var stopped = false
    var updates = 0
    var lastContext: EffectContext?
    func prepare(size: CGSize, scale: CGFloat) {}
    func update(_ context: EffectContext) { updates += 1; lastContext = context }
    func stop() { stopped = true }
    func receive(_ frame: DesktopFrame) { received += 1 }
}
@MainActor final class FakeCapture: DesktopCapturing {
    var onFrame: ((DesktopFrame) -> Void)?
    var onError: ((Error) -> Void)?
    var started = false
    var stopped = false
    var failure: Error?
    func start(displayID: CGDirectDisplayID) async throws { started = true; if let failure { throw failure } }
    func stop() async { stopped = true }
}
@MainActor final class FakeSensor: LidReading {
    var angle: Double? = 125
    let diagnostic = "Test sensor"
    func read() -> Double? { angle }
}
@MainActor final class FakeDisplay: DisplayProviding {
    var screen = NSScreen.screens.first
    var closed = false
    func builtInScreen() -> NSScreen? { screen }
    func lidClosed(now: TimeInterval) -> Bool? { closed }
}
@MainActor final class FakeStore: SettingsStoring {
    var value = UnfoldMyMacSettings()
    func load() -> UnfoldMyMacSettings { value }
    func save(_ settings: UnfoldMyMacSettings) { value = settings }
}
@MainActor func makeRegistry(_ created: @escaping (EffectID, FakeRenderer) -> Void = { _, _ in }) -> EffectRegistry {
    EffectRegistry(entries: [EffectID.frost, .veil, .fade, .curtains, .reverie, .neonCoast, .rise, .current].map { id in
        .init(descriptor: .init(id: id, title: id.rawValue, subtitle: "", detail: "", symbol: "circle", requiresCapture: id == .frost), makeRenderer: {
            let renderer = FakeRenderer(); renderer.animatesWithTime = id == .current; created(id, renderer); return renderer
        })
    })
}
