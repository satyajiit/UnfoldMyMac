import Foundation

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
        case .integer: return number.formatted(Self.integerStyle)
        case .compact: return number.formatted(Self.compactStyle)
        case .text: return content
        }
    }
    /// Built once; a format style resolved per value was a measurable cost in the layer views (P20).
    private static let integerStyle = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
    private static let compactStyle = FloatingPointFormatStyle<Double>.number.locale(Locale(identifier: "en_US")).notation(.compactName).precision(.fractionLength(0...1))
}
