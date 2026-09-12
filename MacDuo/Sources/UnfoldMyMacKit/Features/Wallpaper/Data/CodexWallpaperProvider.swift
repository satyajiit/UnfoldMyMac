import Foundation
import UnfoldMyMacCore

/// Aggregate queries against Codex's local metadata index, through one connection that is reopened only when
/// Codex writes a newer index file or a query fails.
actor CodexWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "codex"
    nonisolated let interval: TimeInterval = 2
    private let root: URL
    private var index: CodexIndex?
    /// Connections opened so far, for tests.
    private(set) var opens = 0
    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")) { self.root = root }
    var indexName: String? { index?.url.lastPathComponent }

    func sample(at date: Date) async throws -> WallpaperDataSample {
        let totals = try read(since: Int64(date.timeIntervalSince1970) - 300)
        return .init(timestamp: date,
            numbers: ["codex.sessions": totals.sessions, "codex.tokens": totals.tokens, "codex.recent": totals.recent,
                      "codex.energy": totals.recent > 0 ? 0.85 : 0.12],
            text: ["codex.activity": totals.recent > 0 ? "SOMETHING'S COOKING." : "WAITING FOR THE NEXT SIDE QUEST.",
                   "codex.scope": "LOCAL CODEX HISTORY · NOT BILLING"],
            status: "Local session and token metadata · refreshed every 2s")
    }
    private func read(since: Int64) throws -> (sessions: Double, tokens: Double, recent: Double) {
        let url = try newestIndex()
        if index?.url != url { index?.close(); index = nil }
        do {
            let open = try index ?? { let opened = try CodexIndex(url: url); index = opened; opens += 1; return opened }()
            return try open.totals(since: since)
        } catch {
            index?.close(); index = nil
            throw error
        }
    }
    private func newestIndex() throws -> URL {
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let candidates = files.filter { $0.lastPathComponent.range(of: #"^state_[0-9]+\.sqlite$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
        guard let url = candidates.first else { throw WallpaperError.unavailable("Open Codex once to create its local activity index.") }
        return url
    }
}
