import AppKit
import UnfoldMyMacCore

enum EffectSessionError: LocalizedError, Equatable {
    case captureUnsupported
    var errorDescription: String? { "This effect does not support desktop frames." }
}

/// One rendered effect on one screen: builds the renderer, installs it in the host and, for capture effects,
/// owns the desktop capture. Teardown is sequenced so a new capture never starts before the previous one has
/// stopped, and a suspended renderer can be reinstalled without rebuilding its GPU resources.
@MainActor final class EffectSession {
    private let registry: EffectRegistry
    private let host: any EffectHosting
    private let displays: any DisplayProviding
    private let gpu: GPUContext?
    private let makeCapture: () -> any DesktopCapturing
    private var capture: (any DesktopCapturing)?
    private var generation = 0
    private var teardown: Task<Void, Never>?
    private var retained: (key: String, renderer: any EffectRenderer)?
    private var countedEffect: EffectID?
    private(set) var renderer: (any EffectRenderer)?
    private(set) var key: String?
    /// The effect actually on screen: Fade stands in for every design under Reduce Transparency (L9).
    private(set) var renderedEffect: EffectID?
    /// Frames received since this effect was first started; restarts of the same effect keep counting (L12).
    private(set) var captureFrames = 0
    var onError: ((Error) -> Void)?

    init(registry: EffectRegistry, host: any EffectHosting, displays: any DisplayProviding, gpu: GPUContext?, makeCapture: @escaping () -> any DesktopCapturing) {
        self.registry = registry; self.host = host; self.displays = displays; self.gpu = gpu; self.makeCapture = makeCapture
    }
    var hasRetainedRenderer: Bool { retained != nil }

    func start(effect: EffectID, screen: NSScreen, reduceTransparency: Bool) {
        let actual = reduceTransparency ? EffectID.fade : effect
        let display = displays.displayID(of: screen) ?? 0
        let nextKey = "\(actual.rawValue):\(display):\(screen.frame):\(screen.backingScaleFactor)"
        guard nextKey != key else { return }
        stop(retaining: true)
        key = nextKey; renderedEffect = actual
        if countedEffect != actual { countedEffect = actual; captureFrames = 0 }
        let token = generation
        do {
            let entry = registry.entry(for: actual)
            let next: any EffectRenderer
            if let retained, retained.key == nextKey { next = retained.renderer; self.retained = nil } else { next = try entry.makeRenderer(gpu) }
            next.prepare(size: screen.frame.size, scale: screen.backingScaleFactor)
            host.install(next.view, on: screen)
            renderer = next
            guard entry.descriptor.requiresCapture else { return }
            guard let consumer = next as? any DesktopFrameSink else { throw EffectSessionError.captureUnsupported }
            startCapture(for: consumer, display: display, token: token)
        } catch { fail(error) }
    }
    func update(_ context: EffectContext) {
        guard let renderer, renderer.ready, context.closure > 0 else { host.hide(); return }
        host.show()
        renderer.update(context)
    }
    /// Releases the renderer and any retained one.
    func stop() { stop(retaining: false) }
    /// Releases the current renderer; `retaining` keeps a previously suspended one for its effect's return.
    func stop(retaining: Bool) {
        generation += 1
        host.hide()
        renderer?.stop(); renderer = nil; key = nil; renderedEffect = nil
        if !retaining { retained = nil }
        let previous = capture
        capture = nil
        previous?.onFrame = nil; previous?.onError = nil
        if let previous {
            let earlier = teardown
            teardown = Task { await earlier?.value; await previous.stop() }
        }
    }
    /// Stops the current renderer but keeps it for the moment its effect comes back, typically after a preview.
    func suspend() {
        guard let renderer, let key else { return }
        stop(retaining: true)
        retained = (key, renderer)
    }

    private func startCapture(for consumer: any DesktopFrameSink, display: CGDirectDisplayID, token: Int) {
        let capture = makeCapture()
        self.capture = capture
        capture.onFrame = { [weak self, weak consumer] frame in
            guard let self, generation == token else { return }
            captureFrames += 1
            consumer?.receive(frame)
        }
        capture.onError = { [weak self] error in
            guard let self, generation == token else { return }
            fail(error)
        }
        let pending = teardown
        Task { [weak self] in
            await pending?.value
            guard let self, generation == token else { return }
            do { try await capture.start(displayID: display) }
            catch {
                guard generation == token else { return }
                fail(error)
            }
        }
    }
    private func fail(_ error: Error) { stop(); onError?(error) }
}
