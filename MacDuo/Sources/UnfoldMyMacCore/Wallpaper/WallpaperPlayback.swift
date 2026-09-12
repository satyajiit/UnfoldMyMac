import Foundation

public struct WallpaperPlayback: Equatable, Sendable {
    public var enabled = false
    public var preview = false
    public var sleeping = false
    public var reducedMotion = false
    public var lowPower = false
    public var thermallyLimited = false
    public var maximumFPS = 60
    public init() {}
    public var framesPerSecond: Int {
        guard (enabled || preview) && !sleeping else { return 0 }
        if reducedMotion { return 1 }
        return min(maximumFPS, lowPower || thermallyLimited ? 30 : 60)
    }
    public var animates: Bool { framesPerSecond > 1 }
    public var shouldSample: Bool { (enabled || preview) && !sleeping }
}
