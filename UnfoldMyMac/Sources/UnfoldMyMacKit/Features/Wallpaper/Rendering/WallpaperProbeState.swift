import Foundation
import Observation
import UnfoldMyMacCore

@MainActor @Observable final class WallpaperProbeState: WallpaperSnapshotSource {
    var snapshot = WallpaperSnapshot()
    var liveInputs = WallpaperLiveInputs()
    private var dynamics = WallpaperInputDynamics()
    func liveTick(_ time: Double) {
        let cycle = time.truncatingRemainder(dividingBy: 12)
        let angle = cycle < 4 ? 110 : (cycle < 7 ? 25 : 110)
        let sound = cycle > 8 && cycle < 8.3 ? 0.1 : 0.01
        dynamics.sample(now: time, lidAngle: Double(angle), rms: sound, sensitivity: 1, battery: 0.6,
                        pluggedIn: cycle > 6, daylight: 0.4, soundEnabled: true, reducedMotion: false)
        liveInputs = dynamics.value
        liveInputs.parallax = SIMD2(sin(time*0.5), cos(time*0.37))
        liveInputs.motionStir = 0.5+0.5*sin(time*0.8)
    }
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
