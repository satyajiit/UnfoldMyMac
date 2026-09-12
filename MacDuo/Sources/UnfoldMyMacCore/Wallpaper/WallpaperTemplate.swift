import Foundation

public struct WallpaperTemplate: Codable, Identifiable, Equatable, Sendable {
    public var version: Int
    public var id: String
    public var title: String
    public var subtitle: String
    public var author: String
    public var tags: [String]
    public var shader: String
    public var accent: UInt32
    public var background: UInt32
    public var image: String?
    public var reactiveMetric: String
    public var reactiveScale: Double
    public var channels: [WallpaperChannel]?
    public var emblem: WallpaperEmblem? = nil
    public var layers: [WallpaperLayer]
    public var setup: [WallpaperSetupRequirement]? = nil
    public var countdown: WallpaperCountdown? = nil
    public var gridBinding: String? = nil
    public var coverImage: String? = nil
    public var informationURL: URL? = nil
    public var allowsCustomBackground: Bool? = nil
    public var dataNamespaces: Set<String> {
        let keys = [reactiveMetric] + (channels ?? []).map(\.metric) + layers.compactMap(\.binding)
        var namespaces = Set(keys.map { String($0.prefix(while: { $0 != "." })) })
        if layers.contains(where: { $0.phrases != nil }) { namespaces.insert("scene") }
        if countdown != nil { namespaces.insert("countdown") }
        if let gridBinding { namespaces.insert(String(gridBinding.prefix(while: { $0 != "." }))) }
        return namespaces
    }

    public func validated() throws -> Self {
        guard version == 1, !id.isEmpty, id.count <= 80,
              !title.isEmpty, title.count <= 80, subtitle.count <= 240,
              author.count <= 80, tags.count <= 12, !shader.isEmpty,
              reactiveScale.isFinite, reactiveScale > 0,
              (channels?.count ?? 0) <= 4, channels?.allSatisfy(\.isValid) ?? true,
              emblem?.isValid ?? true,
              countdown?.isValid ?? true,
              informationURL == nil || (informationURL!.scheme == "https" && informationURL!.host != nil),
              coverImage == nil || coverImage!.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
              gridBinding == nil || (gridBinding!.count <= 100 && gridBinding!.contains(".")),
              (setup?.count ?? 0) <= 5, Set((setup ?? []).map(\.kind)).count == (setup?.count ?? 0),
              (1...32).contains(layers.count), Set(layers.map(\.id)).count == layers.count,
              layers.allSatisfy(\.isValid),
              image == nil || (image!.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        else { throw WallpaperError.invalidTemplate }
        return self
    }
}

/// Four additional normalized signals are available to custom shaders as u.channels.
public struct WallpaperChannel: Codable, Equatable, Sendable {
    public var metric: String
    public var scale: Double
    public var isValid: Bool { !metric.isEmpty && metric.count <= 100 && scale.isFinite && scale > 0 }
}

/// Positions and font sizes are fractions of a 1600 × 1000 design canvas.
/// The compositor letterboxes that canvas so text never stretches on other displays.
public struct WallpaperLayer: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case text, metric, sticker }
    public enum Format: String, Codable, Sendable { case text, integer, compact, percent, gigabytes }
    public var id: String
    public var kind: Kind
    public var content: String
    public var binding: String?
    public var format: Format
    public var x: Double
    public var y: Double
    public var width: Double
    public var size: Double
    public var color: UInt32
    public var rotation: Double
    public var phrases: [String]? = nil
    public var cycleSeconds: Double? = nil
    public var height: Double? = nil
    public var maxLines: Int? = nil

    public var isValid: Bool {
        !id.isEmpty && content.count <= 160 && (binding?.count ?? 0) <= 100 &&
        [x, y, width, size, rotation].allSatisfy(\.isFinite) &&
        (0...1).contains(x) && (0...1).contains(y) && (0.01...1).contains(width) &&
        (0.008...0.2).contains(size) && abs(rotation) <= 30 &&
        (phrases == nil || ((1...12).contains(phrases!.count) && phrases!.allSatisfy { !$0.isEmpty && $0.count <= 160 })) &&
        (cycleSeconds == nil || (cycleSeconds!.isFinite && (4...60).contains(cycleSeconds!))) &&
        (height == nil || (height!.isFinite && height! > 0 && y + height! <= 1)) &&
        (maxLines == nil || (1...6).contains(maxLines!))
    }

    public func value(in snapshot: WallpaperSnapshot, at date: Date = .now, cycles: Bool = true) -> String {
        var literal = content
        if let phrases, !phrases.isEmpty {
            let period = max(4, cycleSeconds ?? 8)
            let index = cycles ? Int(max(0, date.timeIntervalSince1970).truncatingRemainder(dividingBy: period * Double(phrases.count)) / period) : 0
            literal = phrases[index]
        }
        guard let binding else { return literal }
        if format == .text { return snapshot.text(binding, at: date) ?? literal }
        guard let number = snapshot.number(binding, at: date) else { return "—" }
        switch format {
        case .percent: return String(format: "%.0f%%", number)
        case .gigabytes: return String(format: "%.1f GB", number)
        case .integer: return number.formatted(.number.precision(.fractionLength(0)))
        case .compact: return number.formatted(.number.locale(Locale(identifier: "en_US")).notation(.compactName).precision(.fractionLength(0...1)))
        case .text: return content
        }
    }
}
