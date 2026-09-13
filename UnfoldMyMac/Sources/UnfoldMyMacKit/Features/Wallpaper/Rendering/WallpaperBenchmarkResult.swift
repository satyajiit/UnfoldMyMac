import Foundation

struct WallpaperBenchmarkResult {
    let samples: [RenderStats]
    var fps: Double { mean(\.fps) }
    var gpuTime: Double { mean(\.gpuMilliseconds) }
    var worstP95: Double { samples.map(\.p95FrameMilliseconds).max() ?? .infinity }
    func passes(_ options: WallpaperBenchmarkOptions) -> Bool {
        samples.count >= options.seconds-3 && fps >= (options.seconds >= 60 ? 59 : 55) && worstP95 < (options.seconds >= 60 ? 20 : 26)
    }
    func report(template: String) {
        let size = samples.last ?? RenderStats()
        print(String(format: "PRESENTED %@: %.2f fps, worst sample p95 %.2f ms, mean GPU %.2f ms, %d×%d (%d samples)",
                     template, fps, worstP95, gpuTime, size.width, size.height, samples.count))
    }
    private func mean(_ key: KeyPath<RenderStats, Double>) -> Double {
        samples.reduce(0) { $0 + $1[keyPath: key] } / Double(max(1, samples.count))
    }
}
