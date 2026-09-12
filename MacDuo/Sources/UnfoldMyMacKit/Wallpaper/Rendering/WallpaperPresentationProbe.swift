import AppKit
import SwiftUI
import Observation
import UnfoldMyMacCore

extension UnfoldMyMacDiagnostics {
    /// Opt-in, on-screen benchmark. Uses temporary surfaces and never changes saved settings.
    public static func benchmarkWallpaper() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let probe = WallpaperPresentationProbe()
        app.delegate = probe
        withExtendedLifetime(probe) { app.run() }
    }
}

@MainActor @Observable private final class WallpaperProbeState {
    var snapshot = WallpaperSnapshot()
    var samples: [WallpaperRenderStats] = []
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

private struct WallpaperProbeSurface: View {
    let pipeline: WallpaperPipeline
    let state: WallpaperProbeState
    var body: some View {
        WallpaperScene(pipeline: pipeline, snapshot: state.snapshot, fps: 60, onStats: { state.samples.append($0) })
    }
}

@MainActor private final class WallpaperPresentationProbe: NSObject, NSApplicationDelegate {
    private let host = WallpaperDesktopHost()
    func applicationDidFinishLaunching(_ notification: Notification) {
        UnfoldMyMacType.register()
        Task { await measure() }
    }
    private func measure() async {
        do {
            let catalog = try WallpaperShaderCatalog()
            let templates = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates
            let requested = ProcessInfo.processInfo.environment["UNFOLDMYMAC_BENCHMARK_TEMPLATE"]
            guard requested == nil || templates.contains(where: { $0.id == requested }) else {
                print("Unknown wallpaper benchmark template"); exit(1)
            }
            var passed = true
            for template in templates where requested == nil || template.id == requested {
                let pipeline = try WallpaperPipeline(template: template, catalog: catalog)
                let state = WallpaperProbeState()
                state.countdown = template.countdown
                if template.gridBinding == "aurora.oval" {
                    let client = NOAAWeatherClient()
                    async let forecast = client.forecast()
                    async let kp = client.kp()
                    state.auroraState = try await .init(forecast: forecast, kp: kp)
                }
                state.tick(0)
                host.show { WallpaperProbeSurface(pipeline: pipeline, state: state) }
                for tick in 1...8 { try await Task.sleep(for: .seconds(1)); state.tick(tick) }
                let samples = Array(state.samples.dropFirst())
                let fps = samples.reduce(0) { $0 + $1.fps } / Double(max(1, samples.count))
                let p95 = samples.map(\.p95FrameMilliseconds).max() ?? 0
                print(String(format: "PRESENTED %@: %.1f fps, worst sample p95 %.2f ms (%d samples)", template.id, fps, p95, samples.count))
                for window in host.windows {
                    guard let root = window.contentView else { continue }
                    var pending = [root]
                    while let view = pending.popLast() {
                        if view is WallpaperMetalSurface {
                            let frame = view.convert(view.bounds, to: root)
                            print("COVERAGE \(template.id): metal=\(frame), host=\(root.bounds), full=\(frame == root.bounds)")
                            passed = passed && frame == root.bounds
                        }
                        pending.append(contentsOf: view.subviews)
                    }
                }
                fflush(nil)
                passed = passed && fps >= 55 && p95 < 26
                host.stop()
            }
            exit(passed ? 0 : 2)
        } catch { host.stop(); print("Wallpaper benchmark: \(error)"); exit(1) }
    }
}
