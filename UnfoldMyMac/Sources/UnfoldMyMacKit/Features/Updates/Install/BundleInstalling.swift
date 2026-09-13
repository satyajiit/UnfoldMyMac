import Foundation
import UnfoldMyMacCore

/// Puts a verified copy in place of the running one.
///
/// The swap itself happens in another process, after this one has quit. Nothing here mutates the
/// running bundle: the app loads Metal libraries, effect manifests, templates and fonts lazily from
/// its own bundle, so replacing it underneath a live process would break a scene the user opens
/// twenty minutes later, with nothing to connect the failure to the update.
protocol BundleInstalling: Sendable {
    /// Starts the detached installer. The caller quits immediately afterwards.
    func handOff(staged: URL, target: URL, version: AppVersion) async throws
}
