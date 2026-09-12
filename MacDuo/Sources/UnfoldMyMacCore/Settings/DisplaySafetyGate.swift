import Foundation

public struct DisplaySafetyGate: Sendable {
    public enum State: String, Sendable {
        case closed = "Paused · lid closed"
        case noDisplay = "Paused · built-in display unavailable"
        case noSensor = "Paused · sensor unavailable"
        case recovering = "Waiting for built-in display…"
        case ready = "Ready"
    }
    public private(set) var state: State = .recovering
    public var recoveryDelay: TimeInterval = 0.5
    private var readySince: TimeInterval?
    public init() {}
    public mutating func reset() { readySince = nil; state = .recovering }
    @discardableResult public mutating func update(lidClosed: Bool, builtInAvailable: Bool, sensorAvailable: Bool, now: TimeInterval) -> Bool {
        if lidClosed { state = .closed }
        else if !builtInAvailable { state = .noDisplay }
        else if !sensorAvailable { state = .noSensor }
        else {
            if readySince == nil { readySince = now }
            state = now - (readySince ?? now) >= recoveryDelay ? .ready : .recovering
            return state == .ready
        }
        readySince = nil
        return false
    }
}
