import AppKit
import SwiftUI
import Observation
import UnfoldMyMacCore

extension AppDiagnostics {
    /// Opt-in, on-screen benchmark. Uses temporary surfaces and never changes saved settings.
    static func benchmarkWallpaper() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let probe = WallpaperPresentationProbe()
        app.delegate = probe
        withExtendedLifetime(probe) { app.run() }
    }
}

@MainActor @Observable private final class WallpaperProbeState: WallpaperSnapshotSource {
    var snapshot = WallpaperSnapshot()
    var samples: [RenderStats] = []
    var auroraState: NOAAWeatherState?
    var countdown: WallpaperCountdown?
    func tick(_ tick: Int) {
        let date = Date.now
        if let auroraState { snapshot.sources["aurora"] = AuroraWallpaperProvider.snapshot(auroraState, at: date) }
        if let countdown { snapshot.sources["countdown"] = countdown.sample(at: date) }
        snapshot.sources["mac"] = .init(timestamp: date, numbers: ["mac.cpu": Double(30 + tick), "mac.memory": 62])
        snapshot.sources["codex"] = .init(timestamp: date, numbers: ["codex.tokens": Double(tick * 1300), "codex.sessions": 12, "codex.energy": 0.6])
        snapshot.sources["scene"] = .init(timestamp: date, numbers: ["scene.minutes": 1, "scene.remarks": Double(tick), "scene.laps": Double(tick), "scene.energy": 0.5])
        snapshot.sources["claude"] = .init(timestamp: date, numbers: ["claude.tokens": Double(tick * 1200), "claude.sessions": 12, "claude.energy": 0.6])
        snapshot.sources["github"] = .init(timestamp: date, numbers: ["github.repos": 35, "github.followers": 35, "github.pushes": 12, "github.energy": 0.6], text: ["github.handle": "@your-profile", "github.status": "THE PUSH-UPS ARE PAYING OFF."])
        let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "Stop", "Interrupt"]
        let record = CodexHookActivity(session: "benchmark", event: events[tick % events.count], timestamp: date)
        snapshot.sources["activity"] = CodexActivityProvider.snapshot(records: [record], at: date)
    }
}

@MainActor private final class WallpaperPresentationProbe: NSObject, NSApplicationDelegate {
    private let desktop = WallpaperDesktopCoordinator(surfaces: DesktopSurfaceRegistry(), displays: DisplayEnvironment())
    func applicationDidFinishLaunching(_ notification: Notification) {
        UnfoldMyMacType.register()
        Task { await measure() }
    }
    /// Every Metal surface in the window must fill it; a partial surface means the desktop shows a seam.
    private func coversWholeWindow(_ window: NSWindow, template: String) -> Bool {
        guard let root = window.contentView else { return false }
        var pending = [root], covered = true
        while let view = pending.popLast() {
            if view is MetalSurfaceView {
                let frame = view.convert(view.bounds, to: root)
                print("COVERAGE \(template): metal=\(frame), host=\(root.bounds), full=\(frame == root.bounds)")
                covered = covered && frame == root.bounds
            }
            pending.append(contentsOf: view.subviews)
        }
        return covered
    }
    private func measure() async {
        do {
            let gpu = try GPUContext()
            let catalog = WallpaperShaderCatalog()
            let templates = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates
            let requested = ProcessInfo.processInfo.environment["UNFOLDMYMAC_BENCHMARK_TEMPLATE"]
            guard requested == nil || templates.contains(where: { $0.id == requested }) else {
                print("Unknown wallpaper benchmark template"); exit(1)
            }
            var passed = true
            for template in templates where requested == nil || template.id == requested {
                let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
                let state = WallpaperProbeState()
                state.countdown = template.countdown
                if template.gridBinding == "aurora.oval" {
                    let client = NOAAWeatherClient()
                    async let forecast = client.forecast()
                    async let kp = client.kp()
                    state.auroraState = try await .init(forecast: forecast, kp: kp)
                }
                state.tick(0)
                desktop.show(pipeline: pipeline, source: state, framesPerSecond: 60)
                let surface = desktop.surface
                let sampler = Task { for await stats in Observations({ surface.worstStats }) where stats.fps > 0 { state.samples.append(stats) } }
                for tick in 1...8 { try await Task.sleep(for: .seconds(1)); state.tick(tick) }
                sampler.cancel()
                let samples = Array(state.samples.dropFirst())
                let fps = samples.reduce(0) { $0 + $1.fps } / Double(max(1, samples.count))
                let p95 = samples.map(\.p95FrameMilliseconds).max() ?? 0
                print(String(format: "PRESENTED %@: %.1f fps, worst sample p95 %.2f ms (%d samples)", template.id, fps, p95, samples.count))
                for window in desktop.windows { passed = coversWholeWindow(window, template: template.id) && passed }
                fflush(nil)
                passed = passed && fps >= 55 && p95 < 26
                desktop.stop()
            }
            exit(passed ? 0 : 2)
        } catch { desktop.stop(); print("Wallpaper benchmark: \(error)"); exit(1) }
    }
}
