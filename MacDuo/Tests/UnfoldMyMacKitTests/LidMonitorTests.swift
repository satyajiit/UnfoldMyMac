import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func lidMonitorReportsFreshReadingsAndAgesThemOut() {
    let sensor = FakeSensor(); sensor.angle = 120
    let monitor = LidMonitor(makeSensor: { sensor })
    #expect(monitor.angle == nil && !monitor.available && monitor.diagnostic == LidMonitor.initialDiagnostic)
    monitor.read(now: 0)
    #expect(monitor.angle == 120 && monitor.available && monitor.diagnostic == LidMonitor.connectedDiagnostic)
    sensor.angle = nil
    monitor.read(now: 0.9)
    #expect(monitor.angle == 120 && monitor.available, "A reading under a second old still counts")
    monitor.read(now: 1.5)
    #expect(monitor.angle == nil && !monitor.available && monitor.diagnostic == "Test sensor")
}

@Test @MainActor func lidMonitorBacksOffReconnectsAndResetsOnReadOrReopen() {
    let sensor = FakeSensor(); sensor.angle = nil
    var built = 0
    let monitor = LidMonitor(makeSensor: { built += 1; return sensor })
    #expect(built == 1)
    monitor.read(now: 0); #expect(built == 2, "An immediate first reconnect")
    monitor.read(now: 1); #expect(built == 2)
    monitor.read(now: 4); #expect(built == 3, "Four seconds after the first")
    monitor.read(now: 11); #expect(built == 3)
    monitor.read(now: 12); #expect(built == 4, "Eight seconds after the second")
    sensor.angle = 90; monitor.read(now: 13)
    #expect(monitor.available)
    sensor.angle = nil; monitor.read(now: 15)
    #expect(built == 5, "A good reading resets the delay to two seconds")
    #expect(!monitor.available && monitor.angle == nil)
    sensor.angle = 95; monitor.read(now: 16)
    #expect(monitor.available && monitor.angle == 95)
    monitor.reopen()
    #expect(built == 6)
    sensor.angle = nil; monitor.read(now: 16.1)
    #expect(!monitor.available && monitor.angle == nil, "Reopening forgets the stale reading")
}
