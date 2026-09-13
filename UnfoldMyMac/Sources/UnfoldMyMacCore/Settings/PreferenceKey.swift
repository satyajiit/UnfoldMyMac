import Foundation

/// A typed, JSON-encoded preference with its default, its sanitiser and the names it migrates from.
/// Reading never fails: a missing or corrupt value yields the default, and a legacy value is copied
/// under the current name once and then removed.
public struct PreferenceKey<Value: Codable & Sendable>: Sendable {
    public let name: String
    public let legacyNames: [String]
    public let makeDefault: @Sendable () -> Value
    /// Assembles a value from pre-JSON keys when nothing else exists; those keys are then removed.
    public let migrate: (@MainActor (any PreferencesStore) -> Value?)?
    public let sanitize: @Sendable (inout Value) -> Void

    public init(_ name: String, legacyNames: [String] = [], default makeDefault: @escaping @Sendable () -> Value,
                migrate: (@MainActor (any PreferencesStore) -> Value?)? = nil,
                sanitize: @escaping @Sendable (inout Value) -> Void = { _ in }) {
        self.name = name; self.legacyNames = legacyNames; self.makeDefault = makeDefault
        self.migrate = migrate; self.sanitize = sanitize
    }
}
