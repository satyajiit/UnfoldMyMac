import Foundation

/// Stage timings for the launch path, printed when `UNFOLDMYMAC_LAUNCH_TIMING=1`. The first line keeps the
/// format the build script and validation notes grep for; the second breaks the time down by stage.
@MainActor struct LaunchTimeline {
    static let environmentFlag = "UNFOLDMYMAC_LAUNCH_TIMING"
    /// Recorded by `UnfoldMyMacApp.main` before the dependencies and features are built.
    static var processStart: ContinuousClock.Instant?

    let enabled: Bool
    private let start = ContinuousClock.now
    private var last = ContinuousClock.now
    private(set) var stages: [(name: String, duration: Duration)] = []

    init(enabled: Bool = ProcessInfo.processInfo.environment[LaunchTimeline.environmentFlag] == "1") { self.enabled = enabled }

    mutating func mark(_ stage: String) {
        guard enabled else { return }
        let now = ContinuousClock.now
        stages.append((stage, last.duration(to: now))); last = now
    }
    func report(gpu: GPUContext?) {
        guard enabled else { return }
        let shaders = gpu.map { "\($0.libraries.compiledFromSource) shader units compiled from source, \($0.libraries.loadedPrecompiled) precompiled, \($0.pipelines.builtCount) pipeline states" } ?? "no GPU"
        print("LAUNCH applicationDidFinishLaunching→showWindow: \(start.duration(to: .now)); \(shaders)")
        let setup = Self.processStart.map { "main→didFinishLaunching \(Self.milliseconds($0.duration(to: start))) · " } ?? ""
        print("LAUNCH stages: " + setup + stages.map { "\($0.name) \(Self.milliseconds($0.duration))" }.joined(separator: " · "))
        fflush(nil)
    }
    private static func milliseconds(_ duration: Duration) -> String {
        let ms = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
        return String(format: "%.0f ms", ms)
    }
}
