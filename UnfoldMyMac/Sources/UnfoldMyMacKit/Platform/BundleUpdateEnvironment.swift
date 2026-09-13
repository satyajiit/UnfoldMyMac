import Darwin
import Foundation
import UnfoldMyMacCore

/// The live answer to "may this copy replace itself, and is there room to?".
///
/// Checks run cheapest first and the first match wins, because the order decides which explanation
/// the user reads. Everything here is blocking file and code-signing work, so it lives in an actor.
actor BundleUpdateEnvironment: UpdateEnvironmentProbing {
    nonisolated let bundleURL: URL
    private let shortVersion: String?
    private let signatures: any CodeSignatureValidating
    private let downloadDirectory: URL
    private let fileManager: FileManager

    init(bundleURL: URL = Bundle.main.bundleURL.resolvingSymlinksInPath(),
         shortVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
         signatures: any CodeSignatureValidating = SecurityCodeSignatureValidator(),
         downloadDirectory: URL = AppSupportPaths.updates,
         fileManager: FileManager = .default) {
        self.bundleURL = bundleURL; self.shortVersion = shortVersion; self.signatures = signatures
        self.downloadDirectory = downloadDirectory; self.fileManager = fileManager
    }

    private var installRoot: URL { bundleURL.deletingLastPathComponent() }

    func eligibility() async -> UpdateEligibility {
        guard let shortVersion, AppVersion(shortVersion) != nil else { return .blocked(.unreadableVersion) }
        // A `dist` build can be correctly Developer ID signed, so the signature check below would
        // pass and cheerfully overwrite the developer's own working tree.
        if installRoot.lastPathComponent == "dist" { return .blocked(.developmentTree) }
        if isOnReadOnlyVolume { return .blocked(.runningFromDiskImage) }
        // There is no public API for this: SecTranslocate.h is not in the SDK. The path is how the
        // feature works, and a miss falls through to the writability probe, which fails safe.
        if bundleURL.path.contains("/AppTranslocation/") { return .blocked(.translocated) }
        if !signatures.runningApplicationIsRelease() { return .blocked(.developmentBuild) }
        if !canWriteToInstallRoot { return .blocked(.readOnlyLocation) }
        return .eligible
    }

    func facts(currentVersion: AppVersion) async -> UpdateFacts {
        UpdateFacts(eligibility: await eligibility(),
                    currentVersion: currentVersion,
                    systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                    freeSpaceAtInstall: freeSpace(at: installRoot),
                    freeSpaceAtDownload: freeSpace(at: downloadDirectory),
                    installDirectoryWritable: canWriteToInstallRoot,
                    installedByCurrentUser: isOwnedByCurrentUser)
    }

    private var isOnReadOnlyVolume: Bool {
        (try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true
    }

    /// Actually create and remove a directory. File mode bits do not account for ACLs, a read-only
    /// mount, or a managed Mac, and this is the one question that matters.
    private var canWriteToInstallRoot: Bool {
        let probe = installRoot.appendingPathComponent(".unfoldmymac-write-probe-\(UUID().uuidString)")
        do {
            try fileManager.createDirectory(at: probe, withIntermediateDirectories: false)
            try? fileManager.removeItem(at: probe)
            return true
        } catch { return false }
    }

    private var isOwnedByCurrentUser: Bool {
        guard let owner = try? fileManager.attributesOfItem(atPath: bundleURL.path)[.ownerAccountID] as? NSNumber
        else { return true }
        return owner.uint32Value == getuid()
    }

    /// The APFS-aware figure: it accounts for purgeable space, which is what actually decides whether
    /// a large write succeeds.
    private func freeSpace(at url: URL) -> Int64 {
        var probe = url
        while !fileManager.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe = probe.deletingLastPathComponent()
        }
        let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }
}
