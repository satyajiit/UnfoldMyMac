import AppKit
import Testing
@testable import UnfoldMyMacKit

@Test @MainActor func wallpaperCaptureExceptionsAreExplicitAndOwnedByThisProcess() {
    let available: [(CGWindowID, pid_t)] = [(10, 100), (11, 100), (20, 200)]
    #expect(DesktopCaptureFilter.includedIDs(requested: [10,20,30], available: available, process: 100) == [10])
    #expect(DesktopCaptureFilter.includedIDs(requested: [], available: available, process: 100).isEmpty)
    #expect(DesktopCaptureFilter.includedIDs(requested: [11], available: available, process: 100) == [11])
}
