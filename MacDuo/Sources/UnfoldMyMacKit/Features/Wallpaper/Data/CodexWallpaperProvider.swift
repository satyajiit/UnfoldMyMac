import Foundation
import SQLite3
import UnfoldMyMacCore

/// Aggregate queries against Codex's local metadata index. Never selects conversation text.
actor CodexWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "codex"
    nonisolated let interval: TimeInterval = 2
    private let root: URL
    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) { self.root = root }

    func sample(at date: Date) async throws -> WallpaperDataSample {
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let candidates = files.filter { $0.lastPathComponent.range(of: #"^state_[0-9]+\.sqlite$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
        guard let url = candidates.first else { throw WallpaperError.unavailable("Open Codex once to create its local activity index.") }
        let totals = try read(url, since: Int64(date.timeIntervalSince1970) - 300)
        return .init(timestamp: date,
            numbers: ["codex.sessions": totals.sessions, "codex.tokens": totals.tokens, "codex.recent": totals.recent,
                      "codex.energy": totals.recent > 0 ? 0.85 : 0.12],
            text: ["codex.activity": totals.recent > 0 ? "SOMETHING'S COOKING." : "WAITING FOR THE NEXT SIDE QUEST.",
                   "codex.scope": "LOCAL CODEX HISTORY · NOT BILLING"],
            status: "Local session and token metadata · refreshed every 2s")
    }
    private func read(_ url: URL, since: Int64) throws -> (sessions: Double, tokens: Double, recent: Double) {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw WallpaperError.unavailable("Codex's local index is unavailable. It will retry automatically.")
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 100)
        // Desktop/CLI indexes can leave has_user_event at its default even for real sessions.
        // Source identifies those roots; helper threads must not become separate side quests.
        let sql = """
        SELECT COUNT(*), COALESCE(SUM(MAX(0,tokens_used)),0), COALESCE(SUM(updated_at >= ?),0)
        FROM threads WHERE source NOT LIKE '%"subagent"%'
        AND (has_user_event = 1 OR source IN ('cli', 'vscode', 'exec'))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw WallpaperError.unavailable("This Codex index format is not supported yet.")
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, since)
        guard sqlite3_step(statement) == SQLITE_ROW else { throw WallpaperError.unavailable("Codex's local index is busy. Retrying…") }
        return (sqlite3_column_double(statement, 0), sqlite3_column_double(statement, 1), sqlite3_column_double(statement, 2))
    }
}
