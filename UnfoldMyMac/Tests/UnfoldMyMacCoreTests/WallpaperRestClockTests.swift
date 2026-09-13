import Testing
@testable import UnfoldMyMacCore

@Test func focusClockPausesForIdleAndSleepThenRunsARealRestPeriod() {
    var clock = WallpaperRestClock(mode: .focus, minutes: 1)
    clock.tick(uptime: 0, idle: 0)
    for second in 1...30 { clock.tick(uptime: Double(second), idle: 0) }
    #expect(clock.elapsed == 30)
    clock.tick(uptime: 31, idle: 61)
    #expect(clock.elapsed == 30)
    clock.tick(uptime: 5_000, idle: 0)
    #expect(clock.elapsed == 30)
    for second in 5_001...5_030 { clock.tick(uptime: Double(second), idle: 0) }
    #expect(clock.resting && clock.completed == 1 && clock.remaining == 300)
    for second in 5_031...5_330 { clock.tick(uptime: Double(second), idle: 90) }
    #expect(!clock.resting && clock.remaining == 60)
}

@Test func eyeReminderRequiresTwentySecondsAwayAndRejectsInvalidTime() {
    var clock = WallpaperRestClock(mode: .eyes, minutes: 1)
    clock.tick(uptime: 0, idle: 0)
    for second in 1...60 { clock.tick(uptime: Double(second), idle: 0) }
    #expect(clock.resting && clock.progress == 1)
    clock.tick(uptime: 61, idle: 19)
    #expect(clock.resting)
    clock.tick(uptime: .nan, idle: 20)
    #expect(clock.resting)
    clock.tick(uptime: 62, idle: 20)
    #expect(!clock.resting && clock.elapsed == 0)
    clock.tick(uptime: 30, idle: 0)
    #expect(clock.elapsed == 0)
    #expect(WallpaperRestClock(mode: .focus, minutes: .infinity).workSeconds == 1_500)
}
