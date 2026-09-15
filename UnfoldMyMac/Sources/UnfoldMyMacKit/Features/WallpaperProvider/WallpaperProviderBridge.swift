import Foundation
import UnfoldMyMacCore

/// The data bridge between the unsandboxed app and the sandboxed wallpaper extension.
///
/// The extension is spawned by `WallpaperAgent` inside a sandbox, so it cannot read `~/.claude`, Codex
/// history, the IOKit lid angle or the microphone — and `WallpaperHostProxy` offers no push channel. The
/// app therefore writes a snapshot into the extension's own container and posts a Darwin notification;
/// the extension reads the file and re-poses the live scene. This is the only route between the two.
///
/// Both sides use this one type, so the layout cannot drift between writer and reader. `directory` is a
/// property rather than a constant so a test can exercise the whole exchange in a temporary folder
/// instead of against whatever the real extension happens to have written on this Mac.
struct WallpaperProviderBridge: Sendable {
    let directory: URL
    init(directory: URL = WallpaperProviderBridge.defaultDirectory) { self.directory = directory }
    @MainActor static let shared = WallpaperProviderBridge()

    /// Posted by the app after each write. Darwin notifications carry no payload and cross the sandbox,
    /// which is exactly the amount of signalling needed: "the file changed, read it".
    static let notification = AppIdentity.wallpaperExtensionIdentifier + ".snapshot"

    /// What the app sends. Versioned: an unreadable or newer payload leaves the scene on its idle pose
    /// rather than rendering something half-decoded.
    struct Payload: Codable, Equatable {
        static let version = 1
        var version = Payload.version
        /// Raw provider samples. The extension builds the pose itself with `WallpaperPose(template:snapshot:)`,
        /// so the mapping from data to scene lives in exactly one place for both renderers.
        var sources: [String: WallpaperDataSample] = [:]
        var errors: [String: String] = [:]
        var inputs = WallpaperLiveInputs()
        /// The scene the app's own picker has selected, and when. While this is fresh the app is running
        /// and its choice wins; once it goes stale the extension falls back to the choice macOS persisted,
        /// which is what restores the right scene at login with the app not yet launched.
        var templateID: String?
        var selectedAt: Date?

        var snapshot: WallpaperSnapshot {
            var value = WallpaperSnapshot()
            value.sources = sources
            value.errors = errors
            return value
        }
        /// True while the app's selection is recent enough to override the host's persisted choice.
        /// Deliberately the same window the data itself uses: if the samples are stale the app is gone.
        func selectionIsCurrent(at date: Date = .now) -> Bool {
            guard let selectedAt else { return false }
            return WallpaperDataSample.freshness.contains(date.timeIntervalSince(selectedAt))
        }
    }

    /// The extension's container `Documents` directory, spelled from whichever side is asking.
    ///
    /// Inside the sandboxed extension `NSHomeDirectory()` is already the container's `Data` directory; in
    /// the unsandboxed app it is the user's home, so the container path is written out. One expression,
    /// two processes, no shared-constant drift.
    static var defaultDirectory: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if home.path.contains("/Library/Containers/") { return home.appendingPathComponent("Documents", isDirectory: true) }
        return home.appendingPathComponent("Library/Containers/\(AppIdentity.wallpaperExtensionIdentifier)/Data/Documents", isDirectory: true)
    }
    var payloadURL: URL { directory.appendingPathComponent("Snapshot.json") }
    /// Written by the extension on every acquire, read by the app to tell a live provider from a dead one.
    var heartbeatURL: URL { directory.appendingPathComponent("Heartbeat.json") }

    /// What the extension reports back, so the app can prove the provider is actually rendering before
    /// it retires the desktop-window path.
    ///
    /// Decoded field by field rather than by the synthesized initialiser: a heartbeat left on disk by the
    /// previously installed extension is read by the newly installed app, and Swift's synthesized decoder
    /// fails the whole value on one missing key. A version that cannot decode reads as no provider at all,
    /// which is the app taking the desktop back from a provider that is in fact rendering.
    struct Heartbeat: Codable, Equatable {
        var version = Payload.version
        var stampedAt = Date.now
        var templateID: String?
        var contextID: UInt32 = 0
        var surfaces = 0
        /// What the host is showing this provider on: `desktop`, `lockScreen`, or both. This is the only
        /// way to tell a desktop-only provider from one that is also on the lock screen — `surfaces`
        /// counts both, and reading a count as a lock screen is exactly the claim that was wrong. Empty
        /// from an extension too old to report it, which is not the same as a no.
        var roles: [String] = []
        /// The rate the newest surface's display link is configured to, and the rate it is actually
        /// presenting at. The first is an intention; only the second separates a live scene from one
        /// frozen on the single frame drawn before its display link existed.
        var framesPerSecond = 0
        var presentedFPS = 0.0
        /// Non-nil when the provider could not render and the app must show its own notice.
        var failure: String?

        init(stampedAt: Date = .now, templateID: String? = nil, contextID: UInt32 = 0, surfaces: Int = 0,
             roles: [String] = [], framesPerSecond: Int = 0, presentedFPS: Double = 0, failure: String? = nil) {
            self.stampedAt = stampedAt; self.templateID = templateID; self.contextID = contextID
            self.surfaces = surfaces; self.roles = roles; self.framesPerSecond = framesPerSecond
            self.presentedFPS = presentedFPS; self.failure = failure
        }
        private enum CodingKeys: String, CodingKey {
            case version, stampedAt, templateID, contextID, surfaces, roles, framesPerSecond, presentedFPS, failure
        }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            version = try values.decodeIfPresent(Int.self, forKey: .version) ?? Payload.version
            stampedAt = try values.decodeIfPresent(Date.self, forKey: .stampedAt) ?? .distantPast
            templateID = try values.decodeIfPresent(String.self, forKey: .templateID)
            contextID = try values.decodeIfPresent(UInt32.self, forKey: .contextID) ?? 0
            surfaces = try values.decodeIfPresent(Int.self, forKey: .surfaces) ?? 0
            roles = try values.decodeIfPresent([String].self, forKey: .roles) ?? []
            framesPerSecond = try values.decodeIfPresent(Int.self, forKey: .framesPerSecond) ?? 0
            presentedFPS = try values.decodeIfPresent(Double.self, forKey: .presentedFPS) ?? 0
            failure = try values.decodeIfPresent(String.self, forKey: .failure)
        }

        /// Whether the host is showing this provider on the lock screen. The lock screen and the screen
        /// saver are one slot in the system's wallpaper store, so one test answers for both.
        var coversLockScreen: Bool {
            roles.contains { $0.caseInsensitiveCompare(WallpaperProviderRequest.Role.lockScreen.rawValue) == .orderedSame }
        }
    }

    func write(_ payload: Payload) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Atomic: the extension may read at any moment, and a torn file would decode to nothing.
        try encoder.encode(payload).write(to: payloadURL, options: .atomic)
        Self.post()
    }
    func readPayload() -> Payload? {
        decode(Payload.self, at: payloadURL)
    }
    func write(_ heartbeat: Heartbeat) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(heartbeat).write(to: heartbeatURL, options: .atomic)
    }
    func readHeartbeat() -> Heartbeat? {
        decode(Heartbeat.self, at: heartbeatURL)
    }
    private func decode<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Dates go across exactly, as `Date`'s own `Codable` representation, rather than as the ISO8601 the
    /// app uses for feeds it did not write. ISO8601 truncates to whole seconds, and both sides compute
    /// freshness from these timestamps — a truncated stamp would add up to a second of phantom age to
    /// every sample on every hop. Nobody reads this file but the two processes that share this type.
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        return encoder
    }
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(notification as CFString), nil, nil, true)
    }
    /// Calls `handler` on the main queue whenever the other side posts. The observer lives as long as the
    /// process: both sides register once, at startup.
    static func observe(_ handler: @escaping @MainActor () -> Void) {
        let box = Unmanaged.passRetained(Handler(handler)).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), box, { _, observer, _, _, _ in
            guard let observer else { return }
            let handler = Unmanaged<Handler>.fromOpaque(observer).takeUnretainedValue().body
            DispatchQueue.main.async { MainActor.assumeIsolated { handler() } }
        }, notification as CFString, nil, .deliverImmediately)
    }
    private final class Handler {
        let body: @MainActor () -> Void
        init(_ body: @escaping @MainActor () -> Void) { self.body = body }
    }
}
