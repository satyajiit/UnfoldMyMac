import Foundation
import Testing
@testable import UnfoldMyMacCore

@Test(arguments: [(nil, 1.0), (Double.nan, 1), (-10, 0), (8, 0), (59, 0.5), (110, 1), (180, 1)])
func gardenLidNormalization(_ angle: Double?, _ expected: Double) {
    #expect(WallpaperLiveInputs.openness(angle: angle) == expected)
}

private func sample(_ state: inout WallpaperInputDynamics, time: Double, rms: Double = 0, power: Bool? = nil,
                    sound: Bool = true, reduced: Bool = false) {
    state.sample(now: time, lidAngle: 90, rms: rms, sensitivity: 1, battery: nil, pluggedIn: power,
                 daylight: 0.3, soundEnabled: sound, reducedMotion: reduced)
}

@Test func gardenChargingRequiresAnObservedConnectionAndDoesNotReplayAfterSleep() {
    var state = WallpaperInputDynamics()
    sample(&state, time: 0, power: true)
    #expect(state.value.charging == -1)
    #expect(state.value.externalPower == 1)
    sample(&state, time: 1, power: false)
    sample(&state, time: 2, power: true)
    #expect(state.value.charging == 0)
    sample(&state, time: 2.05, power: true)
    #expect(state.value.charging > 0)
    state.suspend()
    sample(&state, time: 10000, power: true)
    #expect(state.value.charging == -1)
    #expect(state.value.externalPower == 1)
    #expect(state.value.battery == 0.65)
}

@Test func gardenExternalPowerSurvivesThePulseAndMissingReadingsUntilUnplugged() {
    var state = WallpaperInputDynamics()
    sample(&state, time: 0, power: false)
    for tick in 1...360 { sample(&state, time: Double(tick)/30, power: true) }
    #expect(state.value.charging == -1 && state.value.externalPower == 1)
    sample(&state, time: 12.04, power: nil)
    #expect(state.value.externalPower == 1, "A missing sample must not extinguish the connected light")
    sample(&state, time: 12.08, power: false)
    #expect(state.value.externalPower == 0)
    sample(&state, time: 12.12, power: true, reduced: true)
    #expect(state.value.externalPower == 1 && state.value.charging == -1)
    state.suspend()
    sample(&state, time: 100, power: nil)
    #expect(state.value.externalPower == 0, "Unknown power after wake must not reuse a stale AC state")
    sample(&state, time: 100.04, power: true)
    #expect(state.value.externalPower == 1 && state.value.charging == -1)
}

@Test func gardenSoundEnvelopeIsBoundedAndPollenNeedsANewPeakAfterCooldown() {
    var state = WallpaperInputDynamics()
    sample(&state, time: 0)
    sample(&state, time: 0.04, rms: 1)
    #expect(state.value.sound > 0 && state.value.sound < 1)
    #expect(state.value.pollen == 0)
    for tick in 2...120 { sample(&state, time: Double(tick)/30, rms: 1) }
    #expect(state.value.pollen == -1, "Sustained noise must not repeatedly emit puffs")
    sample(&state, time: 4.04, rms: 0)
    sample(&state, time: 4.08, rms: 1)
    #expect(state.value.pollen == 0)
    sample(&state, time: 4.12, rms: 1, sound: false)
    #expect(state.value.sound == 0 && state.value.pollen == -1)
    sample(&state, time: 4.16, rms: .infinity)
    #expect(state.value.sound.isFinite)
}

@Test func gardenReduceMotionAndMissingInputsAreCompleteNeutralPoses() {
    var state = WallpaperInputDynamics()
    sample(&state, time: 0, power: false)
    sample(&state, time: 0.04, rms: 1, power: true, reduced: true)
    #expect(state.value.sound == 0 && state.value.pollen == -1 && state.value.charging == -1)
    state.sample(now: 1, lidAngle: nil, rms: .nan, sensitivity: .nan, battery: .nan, pluggedIn: nil,
                 daylight: .nan, soundEnabled: true, reducedMotion: false)
    #expect(state.value.lidOpen == 1 && state.value.battery == 0.65 && state.value.daylight == 0.35)
}

@Test func gardenLocalTimePaletteWrapsSmoothlyAtMidnight() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 13))!
    let before = WallpaperLiveInputs.daylight(at: date.addingTimeInterval(-1), calendar: calendar)
    let after = WallpaperLiveInputs.daylight(at: date.addingTimeInterval(1), calendar: calendar)
    #expect(abs(before-after) < 0.001)
    #expect(WallpaperLiveInputs.daylight(at: date.addingTimeInterval(13*3600), calendar: calendar) == 1)
}
