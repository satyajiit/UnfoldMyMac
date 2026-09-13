import Foundation
import UnfoldMyMacCore

/// Keeps the update folder from accumulating.
///
/// At most one download is kept at a time, so the bound on disk is the size of one disk image rather
/// than one per release ever offered.
enum UpdateSweeper {
    static let staleAfter: TimeInterval = 7 * 24 * 3600

    static func sweep(currentVersion: AppVersion, installRoot: URL, paths: UpdatePaths = .live, now: Date = .now,
                      fileManager: FileManager = .default) {
        let entries = (try? fileManager.contentsOfDirectory(at: paths.root,
                                                            includingPropertiesForKeys: [.contentModificationDateKey],
                                                            options: [])) ?? []
        for url in entries {
            let name = url.lastPathComponent
            if name.hasPrefix("mnt-") {
                // Only ever an empty leftover: a live mount point is detached before it is removed.
                if (try? fileManager.contentsOfDirectory(atPath: url.path))?.isEmpty != false {
                    try? fileManager.removeItem(at: url)
                }
            } else if name.hasPrefix("v") {
                guard let version = AppVersion(String(name.dropFirst())) else { continue }
                if version <= currentVersion || isStale(url, now: now) { try? fileManager.removeItem(at: url) }
            } else if name.hasPrefix("run-") && isStale(url, now: now) {
                try? fileManager.removeItem(at: url)
            }
        }
        sweepStaging(installRoot, now: now, fileManager: fileManager)
    }

    /// A staging directory older than an hour belongs to an install that never finished.
    private static func sweepStaging(_ installRoot: URL, now: Date, fileManager: FileManager) {
        let prefix = ".\(AppIdentity.name)-update-"
        let entries = (try? fileManager.contentsOfDirectory(at: installRoot,
                                                            includingPropertiesForKeys: [.contentModificationDateKey],
                                                            options: [])) ?? []
        for url in entries where url.lastPathComponent.hasPrefix(prefix) {
            if isStale(url, now: now, age: 3600) { try? fileManager.removeItem(at: url) }
        }
    }

    private static func isStale(_ url: URL, now: Date, age: TimeInterval = staleAfter) -> Bool {
        guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return false }
        return now.timeIntervalSince(modified) > age
    }
}
