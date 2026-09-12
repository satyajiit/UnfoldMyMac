import UnfoldMyMacCore

/// Playback from the user's choices and the system's state, in one place.
enum WallpaperPlaybackPolicy {
    /// The desktop cannot be seen while the machine or its screens sleep or another user's session is active.
    static func playback(enabled: Bool, browsing: Bool, maximumFPS: Int, system: SystemState) -> WallpaperPlayback {
        var next = WallpaperPlayback()
        next.enabled = enabled; next.preview = browsing
        next.sleeping = system.displaysUnavailable || system.sessionInactive
        next.reducedMotion = system.reduceMotion; next.lowPower = system.lowPower
        next.thermallyLimited = system.thermallyLimited; next.maximumFPS = maximumFPS
        return next
    }
}
