import AppKit
import UnfoldMyMacCore

/// Decides whether the built-in display may show an effect right now: clamshell and physical-lid safety first,
/// then display presence, then sensor presence (a preview stands in for the sensor), then the recovery delay.
@MainActor struct DisplayGate {
    static let unavailableName = "Built-in display unavailable"
    enum Verdict { case ready(NSScreen), blocked(DisplaySafetyGate.State) }
    private let displays: any DisplayProviding
    private var safety = DisplaySafetyGate()

    init(displays: any DisplayProviding) { self.displays = displays }
    var state: DisplaySafetyGate.State { safety.state }
    var isReady: Bool { safety.state == .ready }
    var screenName: String { displays.builtInScreen()?.localizedName ?? Self.unavailableName }
    mutating func reset() { safety.reset() }
    mutating func evaluate(lidAngle: Double?, sensorAvailable: Bool, previewing: Bool, now: TimeInterval) -> Verdict {
        let screen = displays.builtInScreen()
        let closed = displays.lidClosed(now: now) == true || (sensorAvailable && (lidAngle ?? 180) <= EffectMath.closedLid)
        let ready = safety.update(lidClosed: closed, builtInAvailable: screen != nil, sensorAvailable: sensorAvailable || previewing, now: now)
        if ready, let screen { return .ready(screen) }
        return .blocked(safety.state)
    }
}
