import Foundation
import UnfoldMyMacCore

actor ClaudeWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "claude"
    nonisolated let interval: TimeInterval = 2
    private let root: URL
    nonisolated var fingerprint: String { root.path }
    private let activityDirectory: URL
    private var reader: ClaudeLogReader
    private var activity = ActivityFileCache<ClaudeActivity>(maximumFileBytes: 4096, maximumFiles: 1_000)
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
        activity.records(in: activityDirectory, at: date).compactMap { $0.state(at: date) }
    }
}
