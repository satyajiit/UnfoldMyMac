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
            let options = WallpaperBenchmarkOptions()
            print("HARDWARE \(gpu.device.name); \(ProcessInfo.processInfo.operatingSystemVersionString); stress=\(options.stress); duration=\(options.seconds)s; foreground=\(options.foreground)")
            var passed = true
            for template in templates where requested == nil || template.id == requested {
                let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
                let samples = try await sample(pipeline, options: options)
                let result = WallpaperBenchmarkResult(samples: samples)
                result.report(template: template.id)
                for window in desktop.windows { passed = coversWholeWindow(window, template: template.id) && passed }
                fflush(nil)
                passed = passed && result.passes(options)
                desktop.stop()
            }
            exit(passed ? 0 : 2)
        } catch { desktop.stop(); print("Wallpaper benchmark: \(error)"); exit(1) }
    }
    private func sample(_ pipeline: WallpaperPipeline, options: WallpaperBenchmarkOptions) async throws -> [RenderStats] {
        let state = WallpaperProbeState()
        state.countdown = pipeline.template.countdown
        if pipeline.template.gridBinding == "aurora.oval" {
            let client = NOAAWeatherClient()
            async let forecast = client.forecast()
            async let kp = client.kp()
            state.auroraState = try await .init(forecast: forecast, kp: kp)
        }
        state.tick(0)
        desktop.show(pipeline: pipeline, source: state, framesPerSecond: 60)
        // An explicit diagnostic mode makes real presentation measurable when other apps cover the desktop.
        // The same desktop surfaces and occlusion policy remain in use; closing restores the previous order.
        if options.foreground {
            for window in desktop.windows { window.level = .floating; window.orderFrontRegardless() }
        }
        let surface = desktop.surface
        let sampler = Task { for await stats in Observations({ surface.worstStats }) where stats.fps > 0 { state.samples.append(stats) } }
        let liveTask = Task {
            guard options.stress else { return }
            let start = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                state.liveTick(ProcessInfo.processInfo.systemUptime-start)
                try? await Task.sleep(for: .nanoseconds(33_333_334))
            }
        }
        defer { liveTask.cancel(); sampler.cancel() }
        for tick in 1...options.seconds {
            try await Task.sleep(for: .seconds(1)); state.tick(tick)
            if tick.isMultiple(of: 10) {
                let visible = desktop.windows.filter { $0.occlusionState.contains(.visible) }.count
                print("BENCHMARK \(tick)s: \(state.samples.count) samples, \(visible)/\(desktop.windows.count) visible displays")
                fflush(nil)
            }
        }
        return Array(state.samples.dropFirst())
    }

}
