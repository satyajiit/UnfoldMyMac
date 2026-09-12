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
extension InMemoryPreferencesStore {
    /// The effect settings as the model will load them; assignments persist immediately.
    var settings: UnfoldMyMacSettings {
        get { load(UnfoldMyMacSettings.key) }
        set { save(newValue, for: UnfoldMyMacSettings.key) }
    }
}
@MainActor func makeRegistry(_ created: @escaping (EffectID, FakeRenderer) -> Void = { _, _ in }) -> EffectRegistry {
    EffectRegistry(entries: [EffectID.frost, .veil, .fade, .curtains, .reverie, .neonCoast, .rise, .current].map { id in
        .init(descriptor: .init(id: id, title: id.rawValue, subtitle: "", detail: "", symbol: "circle", requiresCapture: id == .frost), makeRenderer: {
            let renderer = FakeRenderer(); renderer.animatesWithTime = id == .current; created(id, renderer); return renderer
        })
    })
}

@MainActor @Observable final class FakeSystemEnvironment: SystemEnvironmentObserving {
    var state = SystemState()
    var started = false
    func start() { started = true }
    func stop() { started = false }
}
@MainActor final class FakeFilePicker: FilePicking {
    var requests: [FilePickerRequest] = []
    var answer: URL?
    func pick(_ request: FilePickerRequest, completion: @escaping @MainActor (URL?) -> Void) { requests.append(request); completion(answer) }
}
@MainActor final class FakeWorkspace: WorkspaceOpening {
    var opened: [URL] = []
    func open(_ url: URL) { opened.append(url) }
}
@MainActor final class FakeCapturePermission: ScreenCapturePermissionChecking {
    var hasAccess = true
}
/// Builds an effects model on fakes; every seam can be overridden by a test that cares about it.
@MainActor func makeModel(store: InMemoryPreferencesStore = InMemoryPreferencesStore(), registry: EffectRegistry, sensorFactory: @escaping () -> any LidReading = { FakeSensor() },
                          displays: any DisplayProviding = FakeDisplay(), session: EffectSession, environment: any SystemEnvironmentObserving = FakeSystemEnvironment(),
                          filePicker: any FilePicking = FakeFilePicker(), workspace: any WorkspaceOpening = FakeWorkspace(),
                          capturePermission: any ScreenCapturePermissionChecking = FakeCapturePermission(), artworkLibrary: ArtworkLibrary? = nil,
                          clock: @escaping () -> TimeInterval = { 0 }) -> UnfoldMyMacModel {
    UnfoldMyMacModel(dependencies: EffectsDependencies(preferences: store, registry: registry, makeSensor: sensorFactory, displays: displays, session: session,
        environment: environment, filePicker: filePicker, workspace: workspace, capturePermission: capturePermission, artworkLibrary: artworkLibrary, clock: clock))
}

@MainActor final class FakeWallpaperBrowsing: WallpaperBrowsing {
    var browsing = false
    func setBrowsing(_ value: Bool) { browsing = value }
}
