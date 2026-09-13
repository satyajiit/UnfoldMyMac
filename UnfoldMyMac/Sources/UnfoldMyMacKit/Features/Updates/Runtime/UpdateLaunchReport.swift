import Foundation
import UnfoldMyMacCore

/// Reads what the previous install left behind.
///
/// By the time an install succeeds or fails, the process that began it has quit and the one that
/// finished it has exited too. The handoff file is the only channel back, and this turns it into
/// state for the next launch to show.
enum UpdateLaunchReport {
    static func read(currentVersion: AppVersion, at url: URL = UpdatePaths.live.handoff) -> UpdateState? {
        guard let handoff = UpdateHandoff.read(at: url) else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        switch handoff.outcome {
        case .installed:
            return nil
        case .rolledBack:
            return .failed(UpdateFailure(.updateRolledBack, phase: .stage))
        case .pending:
            // Killed mid-flight. If the running version is the one it was installing, it did finish.
            guard AppVersion(handoff.expectedVersion) != currentVersion else { return nil }
            return .failed(UpdateFailure(.updateDidNotFinish(installedVersion: currentVersion.description), phase: .stage))
        }
    }
}
