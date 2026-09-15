import Foundation
import UnfoldMyMacCore

/// Which of the system's two wallpaper slots this provider currently fills, read from the store macOS keeps.
///
/// **Read only, and only ever read.** `WallpaperAgent` owns this file in memory with scheduled flushes, so
/// writing to it is a lost update that can drop wallpaper configuration for every display and Space at
/// once, and `wallpaperexportd` mirrors the damage to the Preboot volume. Reading costs nothing.
///
/// It exists because the heartbeat cannot answer this question on its own. The extension reports the
/// surfaces it holds, and a lock-screen surface exists only while the lock screen is actually being shown
/// — so between unlocking and the next lock there is nothing to report, and "no lock-screen surface right
/// now" would read as "not chosen for the lock screen". macOS offers no public API for the screen saver
/// selection, so this is the only way to tell those two apart. Every failure returns nil rather than a
/// guess, and the caller keeps whatever it already believed.
@MainActor enum WallpaperSlotIndex {
    static var url: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }
    /// How long a reading is reused. The file changes only when the user picks a wallpaper, and the link
    /// asks on every write cycle.
    static let cacheLifetime: TimeInterval = 5
    private nonisolated(unsafe) static var cached: (value: Bool?, at: Date)?

    /// Whether `provider` fills the `Idle` slot — the one the lock screen and the screen saver share — on
    /// any display. Nil when the store could not be read or understood.
    static func coversLockScreen(provider: String = AppIdentity.wallpaperExtensionIdentifier,
                                 at url: URL? = nil, now: Date = .now) -> Bool? {
        if url == nil, let cached, now.timeIntervalSince(cached.at) < cacheLifetime { return cached.value }
        let value = read(provider: provider, at: url ?? Self.url)
        if url == nil { cached = (value, now) }
        return value
    }
    private static func read(provider: String, at url: URL) -> Bool? {
        guard let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        var slots: [[String: Any]] = []
        if let displays = root["Displays"] as? [String: Any] {
            slots += displays.values.compactMap { ($0 as? [String: Any])?["Idle"] as? [String: Any] }
        }
        if let all = (root["AllSpacesAndDisplays"] as? [String: Any])?["Idle"] as? [String: Any] { slots.append(all) }
        // A store with no Idle slot at all is a shape this does not understand, not a no.
        guard !slots.isEmpty else { return nil }
        return slots.contains { slot in
            let choices = ((slot["Content"] as? [String: Any])?["Choices"] as? [[String: Any]]) ?? []
            return choices.contains { ($0["Provider"] as? String) == provider }
        }
    }
    /// Drops the cached reading. For tests, and for the moment the user comes back from System Settings.
    static func invalidate() { cached = nil }
}
