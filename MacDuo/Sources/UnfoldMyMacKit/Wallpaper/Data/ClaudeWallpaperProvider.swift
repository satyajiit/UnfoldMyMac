import Foundation
import UnfoldMyMacCore

actor ClaudeWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "claude"
    nonisolated let interval: TimeInterval = 2
    private let root: URL
    private let activityDirectory: URL
    private var reader: ClaudeLogReader
    init(root: URL, activityDirectory: URL = WallpaperPaths.claudeActivity) {
        self.root = root; self.activityDirectory = activityDirectory
        reader = ClaudeLogReader(cacheDirectory: WallpaperPaths.root.appendingPathComponent("ClaudeCache-v1", isDirectory: true))
    }
    func sample(at date: Date) async throws -> WallpaperDataSample {
        try reader.refresh(root: root, at: date)
        let ledger = reader.ledger
        let states = activities(at: date)
        let working = states.filter { $0 == "WORKING." }.count
        let recent = ledger.activeSessions(at: date)
        let state = working > 0 ? "WORKING." : states.contains("NEEDS YOU.") ? "NEEDS YOU." : states.contains("ALL YOURS.") ? "ALL YOURS." : recent > 0 ? "RECENT ACTIVITY." : "READY WHEN YOU ARE."
        return .init(timestamp: date, numbers: ["claude.tokens": ledger.tokens,
            "claude.sessions": Double(ledger.sessions), "claude.active": Double(working),
            "claude.recent": Double(recent), "claude.energy": working > 0 ? 1 : recent > 0 ? 0.5 : 0.08],
            text: ["claude.status": reader.indexing && states.isEmpty ? "WAKING UP…" : state,
                   "claude.scope": reader.indexing ? "INDEXING \(Int(reader.progress*100))% · COUNTS SO FAR" : "LOCAL LOGS · INCLUDING CACHE"],
            status: reader.cacheError == nil ? (reader.indexing ? "Indexing local history · \(Int(reader.progress*100))% · counts so far" : "Local logs · refreshed every 2s") : "Live · disk cache unavailable")
    }
    private func activities(at date: Date) -> [String] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: activityDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return [] }
        return urls.prefix(1_000).compactMap { url in
            guard url.pathExtension == "json", let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size < 4096, let data = try? Data(contentsOf: url),
                  let activity = try? JSONDecoder().decode(ClaudeActivity.self, from: data) else { return nil }
            return activity.state(at: date)
        }
    }
}
