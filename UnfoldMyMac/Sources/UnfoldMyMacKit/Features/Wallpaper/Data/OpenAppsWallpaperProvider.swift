import AppKit
import UnfoldMyMacCore

/// Only aggregate counts cross the AppKit boundary. App names, icons and window contents are not retained.
struct WorkshopApplication: Sendable {
    let bundleID: String?
    let bundlePath: String?
    let regular: Bool
    var terminated = false

    var identity: String? {
        guard regular, !terminated, bundleID != "com.apple.finder", bundleID != AppIdentity.bundleIdentifier else { return nil }
        return bundleID ?? bundlePath
    }

    static func count(_ applications: [Self]) -> Int { Set(applications.compactMap(\.identity)).count }

    @MainActor static func currentCount() -> Int {
        count(NSWorkspace.shared.runningApplications.map {
            Self(bundleID: $0.bundleIdentifier, bundlePath: $0.bundleURL?.standardizedFileURL.path,
                 regular: $0.activationPolicy == .regular, terminated: $0.isTerminated)
        })
    }
}

/// The data hub owns the one-second cadence and cancels it when neither preview nor desktop consumes it.
actor OpenAppsWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "apps"
    nonisolated let interval: TimeInterval = 1
    private let count: @MainActor @Sendable () -> Int

    init(count: @escaping @MainActor @Sendable () -> Int = { WorkshopApplication.currentCount() }) { self.count = count }

    func sample(at date: Date) async throws -> WallpaperDataSample {
        try Task.checkCancellation()
        let total = max(0, await count())
        try Task.checkCancellation()
        return .init(timestamp: date, numbers: ["apps.count": Double(total), "apps.available": 1])
    }
}
