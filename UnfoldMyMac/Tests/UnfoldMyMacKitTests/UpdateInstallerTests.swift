import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private func makeMount(_ entries: [String], symlinks: [String] = []) throws -> URL {
    let mount = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mnt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
    for name in entries {
        try FileManager.default.createDirectory(at: mount.appendingPathComponent(name), withIntermediateDirectories: true)
    }
    for name in symlinks {
        try FileManager.default.createSymbolicLink(at: mount.appendingPathComponent(name),
                                                   withDestinationURL: URL(fileURLWithPath: "/Applications"))
    }
    return mount
}

@Test func anImageMustHoldExactlyOneRealApplication() throws {
    let mounter = HDIUtilMounter(runner: FakeProcessRunner())

    let good = try makeMount(["UnfoldMyMac.app", ".background"], symlinks: ["Applications"])
    defer { try? FileManager.default.removeItem(at: good) }
    #expect(try mounter.soleApplication(in: good).lastPathComponent == "UnfoldMyMac.app",
            "The drag-to-Applications link and the artwork folder are expected company")

    let empty = try makeMount([".background"])
    defer { try? FileManager.default.removeItem(at: empty) }
    #expect(throws: UpdateError.diskImageLayoutUnexpected) { try mounter.soleApplication(in: empty) }

    let crowded = try makeMount(["UnfoldMyMac.app", "Something.app"])
    defer { try? FileManager.default.removeItem(at: crowded) }
    #expect(throws: UpdateError.diskImageLayoutUnexpected) { try mounter.soleApplication(in: crowded) }
}

@Test func aSymbolicLinkPretendingToBeTheApplicationIsRefused() throws {
    // Following it would verify one bundle and then copy a completely different one.
    let mount = try makeMount([], symlinks: ["UnfoldMyMac.app"])
    defer { try? FileManager.default.removeItem(at: mount) }
    let mounter = HDIUtilMounter(runner: FakeProcessRunner())
    #expect(throws: UpdateError.diskImageLayoutUnexpected) { try mounter.soleApplication(in: mount) }
}

@Test func mountingAlwaysDetachesEvenWhenTheWorkInsideFails() async throws {
    let runner = FakeProcessRunner()
    let mounter = HDIUtilMounter(runner: runner, paths: UpdatePaths(root: URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("mount-\(UUID().uuidString)")))
    struct Boom: Error {}
    _ = try? await mounter.withMountedImage(at: URL(fileURLWithPath: "/tmp/x.dmg")) { _ in throw Boom() }

    let tools = runner.invocations.withLock { $0 }
    #expect(tools.first?.1.first == "attach")
    #expect(tools.contains { $0.1.first == "detach" }, "An image left attached is a mount the user has to clear by hand")
}

@Test func systemToolsAreCalledByAbsolutePathWithAnArgumentVectorAndNeverAShell() async throws {
    let runner = FakeProcessRunner()
    let paths = UpdatePaths(root: URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("tools-\(UUID().uuidString)"))
    let mounter = HDIUtilMounter(runner: runner, paths: paths)
    _ = try? await mounter.withMountedImage(at: URL(fileURLWithPath: "/tmp/a name with spaces.dmg")) { _ in }

    for (executable, arguments) in runner.invocations.withLock({ $0 }) {
        #expect(executable.hasPrefix("/"), "A tool resolved through PATH is a tool an attacker can replace")
        #expect(SystemTool.allowed.contains(executable), "\(executable) is not one of the three permitted tools")
        for argument in arguments {
            #expect(!argument.contains("&&") && !argument.contains(";") && !argument.contains("|"),
                    "Arguments are passed as a vector, so a path is never shell syntax")
        }
    }
    // The awkward file name travels as one argument rather than being quoted into a command line.
    #expect(runner.invocations.withLock { $0 }.first?.1.contains("/tmp/a name with spaces.dmg") == true)
}

@Test func theHandoffNamesTheInstallerAndIsRefusedOnceItIsStale() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("handoff-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let handoff = UpdateHandoff(outcome: .pending, target: "/Applications/UnfoldMyMac.app",
                                staging: root.path, expectedVersion: "1.0.2", nonce: "abc",
                                processIdentifier: 42, createdAt: .now)
    try handoff.write(to: root.appendingPathComponent("handoff.json"))
    let reread = try #require(UpdateHandoff.read(at: root.appendingPathComponent("handoff.json")))
    #expect(reread.isUsable(nonce: "abc"))
    #expect(!reread.isUsable(nonce: "wrong"), "A mismatched nonce is how a stray invocation is turned away")
    #expect(!reread.isUsable(now: Date().addingTimeInterval(600), nonce: "abc"),
            "An old handoff must not let the signed binary move directories on demand")
}

@Test func theLaunchReportTellsTheNextLaunchWhatHappenedToTheLastInstall() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("report-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("handoff.json")
    let current = AppVersion("1.0.1")!

    var handoff = UpdateHandoff(outcome: .installed, target: "/a", staging: "/b", expectedVersion: "1.0.2",
                                nonce: "n", processIdentifier: 1, createdAt: .now)
    try handoff.write(to: url)
    #expect(UpdateLaunchReport.read(currentVersion: AppVersion("1.0.2")!, at: url) == nil, "A success says nothing")

    handoff.outcome = .rolledBack
    try handoff.write(to: url)
    #expect(UpdateLaunchReport.read(currentVersion: current, at: url) == .failed(UpdateFailure(.updateRolledBack, phase: .stage)))

    // Killed part-way through, but the running version is the one it was installing: it did finish.
    handoff.outcome = .pending
    try handoff.write(to: url)
    #expect(UpdateLaunchReport.read(currentVersion: AppVersion("1.0.2")!, at: url) == nil)

    try handoff.write(to: url)
    #expect(UpdateLaunchReport.read(currentVersion: current, at: url)
            == .failed(UpdateFailure(.updateDidNotFinish(installedVersion: "1.0.1"), phase: .stage)))
}
