import Foundation
import UnfoldMyMacCore

actor CodexActivityProvider: WallpaperDataProvider {
    nonisolated let id = "activity"
    nonisolated let interval: TimeInterval = 1
    private let directory: URL
    private var cache = ActivityFileCache<CodexHookActivity>(maximumFileBytes: 65_536, maximumFiles: 2048)
    init(directory: URL = WallpaperPaths.codexActivity) { self.directory = directory }

    func sample(at date: Date) async throws -> WallpaperDataSample {
        Self.snapshot(records: cache.records(in: directory, at: date), at: date)
    }
    static func snapshot(records: [CodexHookActivity], at date: Date) -> WallpaperDataSample {
        let states = records.map { $0.state(at: date) }
        let working = states.filter { $0 == .working }.count, waiting = states.filter { $0 == .waiting }.count
        let state: CodexHookActivity.State = waiting > 0 ? .waiting : working > 0 ? .working : records.max(by: { $0.timestamp < $1.timestamp })?.state(at: date) ?? .idle
        let copy: (String, String, Double, Double)
        switch state {
        case .working: copy = ("LET ME\nCOOK.", "WORKING · HANDS OFF THE SPATULA.", 0.95, 0.2)
        case .waiting: copy = ("YOUR MOVE,\nHUMAN.", "NEEDS APPROVAL · I'LL WAIT RIGHT HERE.", 0.25, 0.5)
        case .completed: copy = ("ORDER UP.\nPATCH SERVED.", "TURN COMPLETE · PLEASE TIP YOUR ROBOT.", 0.6, 0.8)
        case .interrupted: copy = ("PLOT\nINTERRUPTED.", "PAUSED BY YOU · THE DRAMA CAN WAIT.", 0.1, 1)
        case .idle: copy = ("STANDING BY.\nSNACKS READY.", records.isEmpty ? "CONNECT CODEX HOOKS TO GO LIVE." : "IDLE · READY FOR THE NEXT SIDE QUEST.", 0.12, 0)
        }
        return .init(timestamp: date,
            numbers: ["activity.lastEvent": records.map { $0.timestamp.timeIntervalSince1970 }.max() ?? 0,
                      "activity.energy": copy.2, "activity.state": copy.3, "activity.working": Double(working),
                      "activity.waiting": Double(waiting), "activity.turns": Double(records.reduce(0) { $0 + $1.completedTurns }),
                      "activity.tools": Double(records.reduce(0) { $0 + $1.toolEvents })],
            text: ["activity.headline": copy.0, "activity.status": copy.1,
                   "activity.scope": records.isEmpty ? "AWAITING FIRST HOOK · NO ACTIVITY INFERRED" : "LOCAL HOOK HISTORY · STATES EXPIRE AFTER 5 MIN"],
            status: records.isEmpty ? "Waiting for the first trusted Codex hook" : "Receiving local lifecycle events · " + state.rawValue)
    }
}
