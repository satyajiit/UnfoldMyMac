import Foundation

/// Everything the features need to know about the machine, sampled once and kept current by `SystemEnvironment`.
/// Sleep, screen sleep and an inactive login session are separate facts; each feature decides what suspends it.
struct SystemState: Equatable, Sendable {
    var systemAsleep = false
    var screensAsleep = false
    var sessionInactive = false
    var reduceMotion = false
    var reduceTransparency = false
    var lowPower = false
    var thermallyLimited = false
    /// Increments once per debounced display configuration change.
    var displayGeneration = 0
    /// Increments on every active Space change.
    var spaceGeneration = 0

    var displaysUnavailable: Bool { systemAsleep || screensAsleep }
}
