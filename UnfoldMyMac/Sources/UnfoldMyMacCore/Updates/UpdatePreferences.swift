import Foundation

/// What the updater remembers between launches.
///
/// Its own key rather than a field on `UnfoldMyMacSettings`, following the wallpaper preferences:
/// a feature that can be absent entirely should not widen the payload every install already carries.
/// Failures are deliberately not stored — an error that survives a relaunch is no longer true.
public struct UpdatePreferences: Codable, Equatable, Sendable {
    public var automaticChecks = true
    /// Exactly one version, never a set. A newer release replaces it rather than joining it.
    public var skippedVersion: String?
    /// The last version whose sheet was shown. Distinct from `skippedVersion`: skipping hides a
    /// version for good, whereas having seen one only stops the sheet reopening on every window show.
    public var lastSeenVersion: String?
    public var lastCheck: Date?

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case automaticChecks, skippedVersion, lastSeenVersion, lastCheck
    }

    /// Hand written so a payload saved by an older build keeps loading when a field is added.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        automaticChecks = try container.decodeIfPresent(Bool.self, forKey: .automaticChecks) ?? true
        skippedVersion = try container.decodeIfPresent(String.self, forKey: .skippedVersion)
        lastSeenVersion = try container.decodeIfPresent(String.self, forKey: .lastSeenVersion)
        lastCheck = try container.decodeIfPresent(Date.self, forKey: .lastCheck)
    }

    /// Versions persist as their printed form, not as an encoded struct: `defaults read` stays
    /// legible, and adding a field to `AppVersion` cannot orphan what is already on disk.
    public mutating func sanitize(now: Date = .now) {
        if let value = skippedVersion, AppVersion(value) == nil { skippedVersion = nil }
        if let value = lastSeenVersion, AppVersion(value) == nil { lastSeenVersion = nil }
        if let date = lastCheck {
            // A restored backup or a wrong clock must not silence checks for a year.
            if date.timeIntervalSince(now) > 3600 || now.timeIntervalSince(date) > 365 * 24 * 3600 { lastCheck = nil }
        }
    }

    public var skipped: AppVersion? { skippedVersion.flatMap(AppVersion.init) }
    public var lastSeen: AppVersion? { lastSeenVersion.flatMap(AppVersion.init) }

    public static let key = PreferenceKey<UpdatePreferences>(
        "unfoldmymac.updates.v1",
        default: { UpdatePreferences() },
        sanitize: { $0.sanitize() })
}
