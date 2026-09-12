import Foundation

public struct WallpaperDataSample: Codable, Equatable, Sendable {
    /// Samples older than this, or from a clock skewed further ahead, are treated as missing.
    public static let freshness: ClosedRange<TimeInterval> = -5...15
    public var timestamp: Date
    public var numbers: [String: Double]
    public var text: [String: String]
    public var status: String
    public var grids: [String: WallpaperScalarGrid]? = nil
    public init(timestamp: Date, numbers: [String: Double] = [:], text: [String: String] = [:], status: String = "Live", grids: [String: WallpaperScalarGrid]? = nil) {
        self.timestamp = timestamp; self.numbers = numbers; self.text = text; self.status = status
        self.grids = grids
    }
    public func validated(namespace: String) throws -> Self {
        guard numbers.count + text.count <= 128, (grids?.count ?? 0) <= 2,
              grids?.allSatisfy({ $0.key.hasPrefix(namespace + ".") && $0.value.isValid }) ?? true,
              numbers.keys.allSatisfy({ $0.hasPrefix(namespace + ".") }),
              text.keys.allSatisfy({ $0.hasPrefix(namespace + ".") }),
              numbers.values.allSatisfy(\.isFinite), text.values.allSatisfy({ $0.count <= 256 }),
              timestamp.timeIntervalSince1970.isFinite else { throw WallpaperError.invalidData }
        return self
    }
}
