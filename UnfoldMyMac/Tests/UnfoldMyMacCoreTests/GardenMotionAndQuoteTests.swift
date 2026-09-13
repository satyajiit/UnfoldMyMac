import Testing
@testable import UnfoldMyMacCore

@Test func gardenTiltCalibratesClampsAndSettlesWhenReadingsDisappear() {
    var motion = GardenMotionDynamics()
    motion.sample(acceleration: SIMD3(0,0,-1), rotation: .zero, delta: 1.0/30)
    #expect(motion.tilt == .zero && motion.stir == 0)
    for _ in 0..<60 { motion.sample(acceleration: SIMD3(0.2,-0.2,-1), rotation: SIMD3(30,0,0), delta: 1.0/30) }
    #expect(motion.tilt.x > 0.6 && motion.tilt.y > 0.6 && motion.stir > 0.7)
    motion.sample(acceleration: SIMD3(100,-100,-1), rotation: SIMD3(1e8,0,0), delta: 10_000)
    #expect(motion.tilt.x <= 1 && motion.stir <= 1)
    for _ in 0..<120 { motion.sample(acceleration: nil, rotation: nil, delta: 1.0/30) }
    #expect(abs(motion.tilt.x) < 0.001 && motion.stir < 0.001)
    motion.sample(acceleration: SIMD3(0.4,0,-1), rotation: .zero, delta: 1.0/30)
    #expect(abs(motion.tilt.x) < 0.001, "Reconnect must recalibrate instead of jumping")
    motion.reset()
    motion.sample(acceleration: SIMD3(.nan,0,-1), rotation: SIMD3(.infinity,0,0), delta: 1)
    #expect(motion.tilt == .zero && motion.stir == 0)
}

@Test func gardenBreathRequiresSustainedSoundReleaseAndCooldown() {
    var breath = GardenBreathDetector()
    let click = breath.sample(amplitude: 1, delta: 0.033, enabled: true)
    #expect(!click)
    for _ in 0..<20 { let event = breath.sample(amplitude: 0, delta: 1.0/30, enabled: true); #expect(!event) }
    var events = 0
    for _ in 0..<300 { if breath.sample(amplitude: 1, delta: 1.0/30, enabled: true) { events += 1 } }
    #expect(events == 1, "A long sound must only turn one page")
    for _ in 0..<15 { _ = breath.sample(amplitude: 0, delta: 1.0/30, enabled: true) }
    for _ in 0..<20 { if breath.sample(amplitude: 1, delta: 1.0/30, enabled: true) { events += 1 } }
    #expect(events == 2)
    for _ in 0..<300 { let event = breath.sample(amplitude: 1, delta: 1.0/30, enabled: false); #expect(!event) }
}

@Test func gardenLinesFadeOutBeforeSwappingAndPauseWithoutCatchup() {
    var cycle = GardenQuoteCycle()
    let initial = cycle.advance(delta: 0, next: false, animated: true, interval: 15)
    var previous = initial, swaps = 0
    for tick in 0..<120 {
        let current = cycle.advance(delta: 1.0/60, next: tick == 0, animated: true, interval: 15)
        if current.text != previous.text {
            #expect(current.opacity < 0.01 && previous.opacity < 0.01)
            swaps += 1
        }
        #expect((0...1).contains(current.opacity))
        previous = current
    }
    #expect(swaps == 1 && previous.opacity == 1)
    for _ in 0..<300 { previous = cycle.advance(delta: 0.1, next: true, animated: false, interval: 15) }
    #expect(previous.text != initial.text && previous.opacity == 1)
    cycle.pause()
    #expect(cycle.advance(delta: 10_000, next: false, animated: true, interval: 15) == previous)
    for _ in 0..<150 { previous = cycle.advance(delta: 0.1, next: false, animated: true, interval: 15) }
    #expect(previous.opacity < 1, "The automatic interval starts one gentle transition")
}

@Test func gardenChargingFinishesItsEntireRouteOnce() {
    var state = WallpaperInputDynamics()
    for tick in 0...300 {
        state.sample(now: Double(tick)/30, lidAngle: 110, rms: 0, sensitivity: 1, battery: 0.5,
                     pluggedIn: tick > 0, daylight: 0.5, soundEnabled: false, reducedMotion: false)
        if tick == 220 { #expect(state.value.charging > 7 && state.value.charging < 8) }
    }
    #expect(state.value.charging == -1)
}
