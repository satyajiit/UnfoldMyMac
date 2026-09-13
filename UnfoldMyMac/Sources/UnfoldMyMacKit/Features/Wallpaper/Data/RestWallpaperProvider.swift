import Foundation
import CoreGraphics
import UnfoldMyMacCore

actor RestWallpaperProvider: WallpaperDataProvider {
    nonisolated let id: String
    nonisolated let interval: TimeInterval = 1
    nonisolated let fingerprint: String
    private var clock: WallpaperRestClock
    init(mode: WallpaperRestClock.Mode, minutes: Double, restart: String? = nil) {
        id = mode.rawValue
        clock = .init(mode: mode, minutes: minutes)
        fingerprint = "\(mode.rawValue):\(clock.workSeconds):\(restart ?? "initial")"
    }
    func sample(at date: Date) async throws -> WallpaperDataSample {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        clock.tick(uptime: ProcessInfo.processInfo.systemUptime, idle: idle)
        return Self.snapshot(clock, idle: idle, at: date)
    }
    static func snapshot(_ clock: WallpaperRestClock, idle: Double, at date: Date) -> WallpaperDataSample {
        let id = clock.mode.rawValue
        let seconds = Int(ceil(clock.remaining))
        let timer = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        let state: String
        let detail: String
        if clock.mode == .focus {
            state = clock.resting ? "REST AT GRACE" : idle >= 60 ? "FOCUS PAUSED · AWAY" : "FOCUS AT GRACE"
            detail = clock.resting ? "Five minutes to rest. Your next quest starts automatically." : "\(clock.completed) sessions complete · pauses after 1 min away"
        } else {
            state = clock.resting ? "REST YOUR EYES" : "NEXT QUIET MOMENT"
            detail = clock.resting ? "Look away. 20 seconds without input resets the reminder." : "A gentle screen-break reminder · resets after 20 sec away"
        }
        return .init(timestamp: date,
                     numbers: [id + ".progress": clock.progress, id + ".resting": clock.resting ? 1 : 0],
                     text: [id + ".timer": clock.mode == .eyes && clock.resting ? "TAKE A BREATH" : timer,
                            id + ".state": state, id + ".detail": detail])
    }
}
