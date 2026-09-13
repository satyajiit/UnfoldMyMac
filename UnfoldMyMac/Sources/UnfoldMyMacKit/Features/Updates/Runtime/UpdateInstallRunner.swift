import Foundation
import UnfoldMyMacCore

/// Carries one update from "the user clicked Update" to "a verified copy is staged".
///
/// Reports progress through `report` and returns the state the model should settle on, so the model
/// stays the single owner of `state` without also holding the procedure that produces it.
@MainActor struct UpdateInstallRunner {
    var flow = UpdateInstallFlow()
    var paths = UpdatePaths.live
    var environment: any UpdateEnvironmentProbing
    var currentVersion: AppVersion
    var now: @Sendable () -> Date = { .now }

    func run(_ release: UpdateRelease, report: @escaping @MainActor (UpdateState) -> Void) async -> UpdateState {
        // Re-checked here, not just at discovery: an offer can outlive a manual upgrade, and disk
        // space or write permission can change between finding an update and accepting it.
        let facts = await environment.facts(currentVersion: currentVersion)
        switch UpdatePlan.decide(release, facts: facts) {
        case .blocked(let block): return .unsupported(block)
        case .alreadyCurrent: return .upToDate(currentVersion, checkedAt: now())
        case .refuse(let error): return .failed(UpdateFailure(error, phase: error.phase))
        case .proceed: break
        }
        guard let lock = UpdateLock(at: paths.lock) else {
            return .failed(UpdateFailure(.anotherCopyIsUpdating, phase: .download))
        }
        // Held for the whole download, which is what keeps a second instance out of the same one.
        defer { lock.release() }
        report(.downloading(release, received: 0, total: release.assetSize))
        do {
            let staged = try await flow.run(
                release, target: environment.bundleURL, systemMajorVersion: facts.systemMajorVersion,
                onProgress: { received, expected in
                    Task { @MainActor in report(.downloading(release, received: received, total: expected)) }
                },
                onVerifying: { Task { @MainActor in report(.verifying(release)) } })
            return .readyToRelaunch(release, staged: staged)
        } catch is CancellationError {
            return .available(release)
        } catch let error as UpdateError {
            return .failed(UpdateFailure(error, phase: error.phase))
        } catch {
            return .failed(UpdateFailure(UpdateNetworkError.mapped(error), phase: .download))
        }
    }
}
