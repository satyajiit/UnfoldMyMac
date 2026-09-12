import Foundation

public enum EffectManifestError: LocalizedError, Equatable {
    case unsupportedVersion(Int), duplicateID(String), invalidEntry(String), missingEffect(String)
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "The effect catalog is version \(version); this build reads version \(EffectManifest.currentVersion)."
        case .duplicateID(let id): "The effect catalog lists ‘\(id)’ twice."
        case .invalidEntry(let id): "The effect catalog entry ‘\(id)’ is incomplete."
        case .missingEffect(let id): "The effect catalog names ‘\(id)’ as a fallback but does not declare it."
        }
    }
}

/// `Resources/Effects/Effects.json`: the bundled effects and which of them stand in when a choice cannot be honoured.
public struct EffectManifest: Decodable, Sendable {
    public static let currentVersion = 1
    public let version: Int
    /// The effect a fresh install selects.
    public let `default`: EffectID
    /// The non-capture effect that replaces an unknown or removed choice.
    public let fallback: EffectID
    /// The effect rendered for every design while Reduce Transparency is on.
    public let reduceTransparencyFallback: EffectID
    public let effects: [EffectManifestEntry]

    public init(version: Int = EffectManifest.currentVersion, default: EffectID, fallback: EffectID, reduceTransparencyFallback: EffectID, effects: [EffectManifestEntry]) {
        self.version = version; self.default = `default`; self.fallback = fallback
        self.reduceTransparencyFallback = reduceTransparencyFallback; self.effects = effects
    }
    public static func decode(_ data: Data) throws -> EffectManifest {
        try JSONDecoder().decode(EffectManifest.self, from: data).validated()
    }
    public func validated() throws -> EffectManifest {
        guard version == Self.currentVersion else { throw EffectManifestError.unsupportedVersion(version) }
        var seen = Set<EffectID>()
        for entry in effects {
            guard entry.isValid else { throw EffectManifestError.invalidEntry(entry.id.rawValue) }
            guard seen.insert(entry.id).inserted else { throw EffectManifestError.duplicateID(entry.id.rawValue) }
        }
        for id in [`default`, fallback, reduceTransparencyFallback] where !seen.contains(id) { throw EffectManifestError.missingEffect(id.rawValue) }
        return self
    }
}
