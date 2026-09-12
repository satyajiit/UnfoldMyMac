import AppKit
import UnfoldMyMacCore

enum EffectSessionError: LocalizedError, Equatable {
    case captureUnsupported
    var errorDescription: String? { "This effect does not support desktop frames." }
}

@MainActor final class EffectSession {
    private let registry: EffectRegistry
    private let host: any EffectHosting
    private let displays: any DisplayProviding
    private let gpu: GPUContext?
    private let makeCapture: () -> any DesktopCapturing
    private var capture: (any DesktopCapturing)?
    private var generation = 0
    private(set) var renderer: (any EffectRenderer)?
    private(set) var key: String?
    private(set) var captureFrames = 0
    var onError: ((Error) -> Void)?

    init(registry: EffectRegistry, host: any EffectHosting, displays: any DisplayProviding, gpu: GPUContext?, makeCapture: @escaping () -> any DesktopCapturing) {
        self.registry = registry; self.host = host; self.displays = displays; self.gpu = gpu; self.makeCapture = makeCapture
    }
    func start(effect: EffectID, screen: NSScreen, reduceTransparency: Bool) {
        let actual = reduceTransparency ? EffectID.fade : effect
        let display = displays.displayID(of: screen) ?? 0
        let nextKey = "\(actual.rawValue):\(display):\(screen.frame):\(screen.backingScaleFactor)"
        guard nextKey != key else { return }
        stop()
        key = nextKey
        let token = generation
        do {
            let entry = registry.entry(for: actual)
            let next = try entry.makeRenderer(gpu)
            next.prepare(size: screen.frame.size, scale: screen.backingScaleFactor)
            host.install(next.view, on: screen)
            renderer = next
            if entry.descriptor.requiresCapture {
                guard let consumer = next as? any DesktopFrameSink else {
                    throw EffectSessionError.captureUnsupported
                }
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
                Task { [weak self] in
                    do { try await capture.start(displayID: display) }
                    catch {
                        guard let self, generation == token else { return }
                        fail(error)
                    }
                }
            }
        } catch { fail(error) }
    }
    func update(_ context: EffectContext) {
        guard let renderer, renderer.ready, context.closure > 0 else { host.hide(); return }
        host.show()
        renderer.update(context)
    }
    func stop() {
        generation += 1
        host.hide()
        renderer?.stop(); renderer = nil; key = nil; captureFrames = 0
        let previous = capture
        capture = nil
        previous?.onFrame = nil; previous?.onError = nil
        if let previous { Task { await previous.stop() } }
    }
    private func fail(_ error: Error) { stop(); onError?(error) }
}
