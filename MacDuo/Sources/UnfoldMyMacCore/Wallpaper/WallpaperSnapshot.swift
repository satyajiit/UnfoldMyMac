import Foundation

public struct WallpaperSnapshot: Equatable, Sendable {
    public var sources: [String: WallpaperDataSample] = [:]
    public var errors: [String: String] = [:]
    public init() {}
    public func number(_ key: String, at date: Date = .now) -> Double? {
        source(for: key, at: date)?.numbers[key]
    }
    public func text(_ key: String, at date: Date = .now) -> String? {
        source(for: key, at: date)?.text[key]
    }
    public func grid(_ key: String, at date: Date = .now) -> WallpaperScalarGrid? {
        source(for: key, at: date)?.grids?[key]
    }
    private func source(for key: String, at date: Date) -> WallpaperDataSample? {
        let namespace = String(key.prefix(while: { $0 != "." }))
        guard errors[namespace] == nil, let sample = sources[namespace],
              WallpaperDataSample.freshness.contains(date.timeIntervalSince(sample.timestamp)) else { return nil }
        return sample
    }
}
