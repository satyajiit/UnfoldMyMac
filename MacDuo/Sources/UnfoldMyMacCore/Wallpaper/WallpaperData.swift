import Foundation

/// Providers own I/O. Renderers receive immutable, namespaced values only.
public protocol WallpaperDataProvider: Sendable {
    var id: String { get }
    var interval: TimeInterval { get }
    func sample(at date: Date) async throws -> WallpaperDataSample
}

public struct WallpaperDataSample: Codable, Equatable, Sendable {
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
              (-5...15).contains(date.timeIntervalSince(sample.timestamp)) else { return nil }
        return sample
    }
}

public enum WallpaperError: Error, LocalizedError, Equatable {
    case invalidData, invalidTemplate, duplicateID(String), missingShader(String), unavailable(String)
    public var errorDescription: String? {
        switch self {
        case .invalidData: "The data source returned an invalid or unsupported snapshot."
        case .invalidTemplate: "This wallpaper template is invalid or uses an unsupported version."
        case .duplicateID(let id): "A wallpaper with the ID ‘\(id)’ is already registered."
        case .missingShader(let id): "The renderer ‘\(id)’ is not installed."
        case .unavailable(let reason): reason
        }
    }
}
