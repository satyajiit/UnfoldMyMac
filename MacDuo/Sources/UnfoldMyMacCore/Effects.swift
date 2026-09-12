import Foundation

public struct EffectID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let frost = EffectID(rawValue: "frost")
    public static let veil = EffectID(rawValue: "veil")
    public static let fade = EffectID(rawValue: "fade")
    public static let curtains = EffectID(rawValue: "curtains")
    public static let reverie = EffectID(rawValue: "reverie")
    public static let neonCoast = EffectID(rawValue: "neon-coast")
    public static let rise = EffectID(rawValue: "rise")
    public static let current = EffectID(rawValue: "current")
}

public enum EffectCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case glass, image, motion
    public var id: String { rawValue }
    public var title: String {
        switch self { case .glass: "Glass & Light"; case .image: "Image Art"; case .motion: "Motion & 3D" }
    }
}

/// A reveal is independent of its image. Stable string keys are used in catalogs and settings.
public enum ArtRevealMotion: String, CaseIterable, Codable, Sendable, Identifiable {
    case curved, diagonal, straight, burst
    public var id: String { rawValue }
    public var shaderIndex: UInt32 {
        switch self { case .curved: 0; case .diagonal: 1; case .straight: 2; case .burst: 3 }
    }
    public var title: String {
        switch self { case .curved: "Sculpted"; case .diagonal: "Diagonal"; case .straight: "Slide"; case .burst: "Burst" }
    }
}

public struct EffectDescriptor: Identifiable, Sendable {
    public let id: EffectID
    public let title: String
    public let subtitle: String
    public let detail: String
    public let symbol: String
    public let requiresCapture: Bool
    public let parameterTitle: String
    public let renderingLabel: String
    public let category: EffectCategory
    public let tags: [String]
    public let author: String
    public let credit: String
    public let coverURL: URL?
    public let hasContinuousMotion: Bool
    public let isImported: Bool
    public let defaultReveal: ArtRevealMotion?

    public func matches(query: String, category: EffectCategory? = nil, tag: String? = nil) -> Bool {
        guard category == nil || self.category == category,
              tag.map(tags.contains) ?? true else { return false }
        let haystack = ([title, subtitle, detail, author, credit, self.category.title] + tags).joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { haystack.localizedStandardContains(String($0)) }
    }

    public init(id: EffectID, title: String, subtitle: String, detail: String, symbol: String, requiresCapture: Bool = false,
                parameterTitle: String = "Intensity", renderingLabel: String? = nil,
                category: EffectCategory = .glass, tags: [String] = [], author: String = AppIdentity.name,
                credit: String = "", coverURL: URL? = nil, isImported: Bool = false, hasContinuousMotion: Bool = false, defaultReveal: ArtRevealMotion? = nil) {
        self.id = id; self.title = title; self.subtitle = subtitle
        self.detail = detail; self.symbol = symbol; self.requiresCapture = requiresCapture
        self.category = category; self.tags = tags; self.author = author; self.credit = credit
        self.hasContinuousMotion = hasContinuousMotion
        self.coverURL = coverURL; self.isImported = isImported; self.defaultReveal = defaultReveal
        self.parameterTitle = parameterTitle
        self.renderingLabel = renderingLabel ?? (requiresCapture ? "Live capture" : "Native")
    }
}

public struct EffectParameters: Codable, Equatable, Sendable {
    public var strength: Double
    public var reveal: ArtRevealMotion?
    public init(strength: Double = 1, reveal: ArtRevealMotion? = nil) { self.strength = strength; self.reveal = reveal }
    private enum CodingKeys: String, CodingKey { case strength, reveal }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        strength = try values.decodeIfPresent(Double.self, forKey: .strength) ?? 1
        reveal = try values.decodeIfPresent(ArtRevealMotion.self, forKey: .reveal)
    }
}

/// Coordinates are screen-aligned. Closure is calibrated visual progress: 0 clear, 1 complete.
public struct EffectContext: Equatable, Sendable {
    public let closure: Double
    public let parameters: EffectParameters
    public let reduceTransparency: Bool
    public let time: TimeInterval
    public let reduceMotion: Bool
    public init(closure: Double, parameters: EffectParameters = .init(), reduceTransparency: Bool = false,
                time: TimeInterval = 0, reduceMotion: Bool = false) {
        self.closure = min(1, max(0, closure.isFinite ? closure : 0))
        self.parameters = parameters
        self.reduceTransparency = reduceTransparency
        self.time = time.isFinite ? max(0, time) : 0
        self.reduceMotion = reduceMotion
    }
    public var motion: Double {
        let x = min(1, closure * 2)
        return (x + EffectMath.smoothstep(x)) / 2
    }
    public var finalFade: Double { max(0, closure * 2 - 1) }
    public var strength: Double { min(1, max(0, parameters.strength.isFinite ? parameters.strength : 1)) }
}

public enum EffectMath {
    public static let closedLid = 5.0
    public static let defaultActivation = 125.0
    public static func closure(lid: Double, activation: Double) -> Double {
        guard lid.isFinite, activation.isFinite else { return 0 }
        return min(1, max(0, (activation - lid) / max(1, activation - closedLid)))
    }
    /// Finish the visual sequence before physical lid travel ends; hold the final state afterward.
    public static func calibratedClosure(_ raw: Double, completionFraction: Double) -> Double {
        guard raw.isFinite else { return 0 }
        let end = completionFraction.isFinite ? min(1, max(0.4, completionFraction)) : 0.8
        return min(1, max(0, raw / end))
    }
    /// The inclusive trigger gets a subtle first frame; there is no invisible travel below it.
    /// Preview remains fully clear at zero, and live completion still lands at the configured angle.
    public static func liveProgress(lid: Double, activation: Double, completionFraction: Double) -> Double {
        guard lid.isFinite, activation.isFinite, lid <= activation else { return 0 }
        let progress = calibratedClosure(closure(lid: lid, activation: activation), completionFraction: completionFraction)
        let onset = 0.004
        return onset + (1 - onset) * progress
    }
    public static func completionAngle(activation: Double, completionFraction: Double) -> Double {
        let end = completionFraction.isFinite ? min(1, max(0.4, completionFraction)) : 0.8
        return activation - (activation - closedLid) * end
    }
    public static func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }
    public static func blurRadius(edge: Double, context: EffectContext) -> Double {
        72 * context.motion * pow(min(1, max(0, edge)), 1.35) * context.strength
    }
    public static func darkening(edge: Double, context: EffectContext) -> Double {
        let gradient = min(1, max(0, (edge - 0.2) / 0.8))
        let local = min(1, context.motion * pow(gradient, 1.35) * 2 * context.strength)
        return 1 - (1 - local) * (1 - context.finalFade)
    }
    public static func playClosure(seconds: Double) -> Double {
        let t = seconds.truncatingRemainder(dividingBy: 8.6)
        if t < 1.2 { return 0 }
        if t < 4.3 { return (1 - cos((t - 1.2) / 3.1 * .pi)) / 2 }
        if t < 5.5 { return 1 }
        return (1 + cos((t - 5.5) / 3.1 * .pi)) / 2
    }
}
