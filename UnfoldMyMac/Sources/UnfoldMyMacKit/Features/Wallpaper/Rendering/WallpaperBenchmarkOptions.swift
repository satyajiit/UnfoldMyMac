import Foundation

struct WallpaperBenchmarkOptions {
    var seconds: Int
    var stress: Bool
    var foreground: Bool
    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        seconds = min(300, max(8, Int(environment["UNFOLDMYMAC_BENCHMARK_SECONDS"] ?? "8") ?? 8))
        stress = environment["UNFOLDMYMAC_BENCHMARK_STRESS"] == "1"
        foreground = environment["UNFOLDMYMAC_BENCHMARK_FOREGROUND"] == "1"
    }
}
