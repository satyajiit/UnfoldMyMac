import Foundation
import UnfoldMyMacCore

/// Reads the lid angle through a `LidReading` and reopens a missing sensor with exponential backoff (L2), so a
/// Mac without the report is not rebuilding an HID manager every two seconds forever.
@MainActor final class LidMonitor {
    static let initialDiagnostic = "Checking lid sensor…"
    static let connectedDiagnostic = "Lid sensor connected · read-only"
    private let makeSensor: () -> any LidReading
    private var sensor: any LidReading
    private(set) var angle: Double?
    private(set) var available = false
    private(set) var diagnostic = LidMonitor.initialDiagnostic
    private var lastReading = -Double.infinity
    private var lastReconnect = -Double.infinity
    private var reconnectDelay = EffectTuning.sensorReconnectDelay

    init(makeSensor: @escaping () -> any LidReading) {
        self.makeSensor = makeSensor
        sensor = makeSensor()
    }
    /// Reads once. A reading older than `EffectTuning.sensorStaleAfter` marks the sensor unavailable.
    func read(now: TimeInterval) {
        if let value = sensor.read() {
            angle = value; lastReading = now
            reconnectDelay = EffectTuning.sensorReconnectDelay
        } else if now - lastReconnect >= reconnectDelay {
            lastReconnect = now
            reconnectDelay = min(EffectTuning.sensorReconnectCeiling, reconnectDelay * 2)
            sensor = makeSensor()
        }
        available = now - lastReading <= EffectTuning.sensorStaleAfter
        if !available { angle = nil }
        diagnostic = available ? Self.connectedDiagnostic : sensor.diagnostic
    }
    /// After wake the HID device may have been re-enumerated: reopen it and forget the stale reading.
    func reopen() {
        lastReading = -.infinity
        reconnectDelay = EffectTuning.sensorReconnectDelay
        sensor = makeSensor()
    }
}
