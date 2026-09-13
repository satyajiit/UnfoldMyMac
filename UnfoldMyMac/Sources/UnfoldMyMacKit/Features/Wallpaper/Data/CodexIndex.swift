import Foundation
import SQLite3
import UnfoldMyMacCore

/// One read-only connection to a Codex state index with its aggregate statement prepared once (P19).
/// Never selects conversation text. Confined to the provider actor.
final class CodexIndex {
    let url: URL
    private var database: OpaquePointer?
    private var statement: OpaquePointer?
    // Desktop/CLI indexes can leave has_user_event at its default even for real sessions.
    // Source identifies those roots; helper threads must not become separate side quests.
    private static let sql = """
    SELECT COUNT(*), COALESCE(SUM(MAX(0,tokens_used)),0), COALESCE(SUM(updated_at >= ?),0)
    FROM threads WHERE source NOT LIKE '%"subagent"%'
    AND (has_user_event = 1 OR source IN ('cli', 'vscode', 'exec'))
    """

    init(url: URL) throws {
        self.url = url
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            close(); throw WallpaperError.unavailable("Codex's local index is unavailable. It will retry automatically.")
        }
        sqlite3_busy_timeout(database, 100)
        guard sqlite3_prepare_v2(database, Self.sql, -1, &statement, nil) == SQLITE_OK else {
            close(); throw WallpaperError.unavailable("This Codex index format is not supported yet.")
        }
    }
    /// The statement is reset as soon as the row is read so no read lock outlives the sample and Codex's own
    /// writes are never held up between polls.
    func totals(since: Int64) throws -> (sessions: Double, tokens: Double, recent: Double) {
        defer { sqlite3_reset(statement); sqlite3_clear_bindings(statement) }
        sqlite3_bind_int64(statement, 1, since)
        guard sqlite3_step(statement) == SQLITE_ROW else { throw WallpaperError.unavailable("Codex's local index is busy. Retrying…") }
        return (sqlite3_column_double(statement, 0), sqlite3_column_double(statement, 1), sqlite3_column_double(statement, 2))
    }
    func close() {
        if statement != nil { sqlite3_finalize(statement); statement = nil }
        if database != nil { sqlite3_close(database); database = nil }
    }
    deinit { close() }
}
