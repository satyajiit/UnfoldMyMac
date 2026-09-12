import Foundation
import Testing
import UnfoldMyMacCore

private struct Step: Sendable {
    enum Command: Sendable { case begin(EffectID, enabled: Bool), remember(Bool), play, pause, scrub(Double), advance(Double), end(PreviewController.Restore) }
    let command: Command
    let previewing: Bool, playing: Bool, effect: EffectID?, closure: Double
    let transition: PreviewController.Transition?
    let restored: Bool?
    init(_ command: Command, previewing: Bool, playing: Bool = false, effect: EffectID? = nil, closure: Double = 0,
         transition: PreviewController.Transition? = nil, restored: Bool? = nil) {
        self.command = command; self.previewing = previewing; self.playing = playing; self.effect = effect; self.closure = closure
        self.transition = transition; self.restored = restored
    }
}

@Test func previewControllerFollowsItsTransitionTable() {
    let quarter = EffectMath.playClosure(seconds: EffectMath.playSeconds(closure: 0.4) + 0.5)
    let table: [Step] = [
        .init(.play, previewing: false), // Playing outside a preview is a no-op.
        .init(.begin(.veil, enabled: false), previewing: true, effect: .veil, transition: .started),
        .init(.begin(.veil, enabled: true), previewing: true, effect: .veil, transition: .unchanged),
        .init(.scrub(0.4), previewing: true, effect: .veil, closure: 0.4),
        .init(.play, previewing: true, playing: true, effect: .veil, closure: 0.4),
        .init(.advance(0.5), previewing: true, playing: true, effect: .veil, closure: quarter),
        .init(.pause, previewing: true, effect: .veil, closure: quarter),
        .init(.advance(0.5), previewing: true, effect: .veil, closure: quarter), // Paused playback holds.
        .init(.begin(.rise, enabled: true), previewing: true, effect: .rise, transition: .switched), // Switching resets the pose.
        .init(.scrub(2), previewing: true, effect: .rise, closure: 1),
        .init(.scrub(-1), previewing: true, effect: .rise, closure: 0),
        .init(.end(.previous), previewing: false, restored: false), // Remembered from the first begin, not the switch.
        .init(.begin(.frost, enabled: true), previewing: true, effect: .frost, transition: .started),
        .init(.remember(false), previewing: true, effect: .frost),
        .init(.end(.previous), previewing: false, restored: false), // L1: the choice made during the preview wins.
        .init(.begin(.frost, enabled: true), previewing: true, effect: .frost, transition: .started),
        .init(.end(.disabled), previewing: false, restored: false), // P16: the chosen effect failed.
        .init(.begin(.frost, enabled: true), previewing: true, effect: .frost, transition: .started),
        .init(.end(.previous), previewing: false, restored: true),
    ]
    var controller = PreviewController()
    for (index, step) in table.enumerated() {
        var transition: PreviewController.Transition?
        var restored: Bool?
        switch step.command {
        case .begin(let id, let enabled): transition = controller.begin(effect: id, enabled: enabled)
        case .remember(let value): controller.rememberEnabled(value)
        case .play: controller.play()
        case .pause: controller.pause()
        case .scrub(let value): controller.scrub(value)
        case .advance(let delta): controller.advance(by: delta)
        case .end(let restore): restored = controller.end(restoring: restore)
        }
        #expect(controller.isPreviewing == step.previewing, "step \(index)")
        #expect(controller.isPlaying == step.playing, "step \(index)")
        #expect(controller.effectID == step.effect, "step \(index)")
        #expect(abs(controller.closure - step.closure) < 1e-9, "step \(index): \(controller.closure)")
        if let expected = step.transition { #expect(transition == expected, "step \(index)") }
        if let expected = step.restored { #expect(restored == expected, "step \(index)") }
    }
}

@Test func playbackResumesFromTheScrubbedPositionOnTheClosingRamp() {
    for closure in stride(from: 0.0, through: 1.0, by: 0.125) {
        let seconds = EffectMath.playSeconds(closure: closure)
        #expect((1.2...4.3).contains(seconds))
        #expect(abs(EffectMath.playClosure(seconds: seconds) - closure) < 1e-9)
    }
    #expect(EffectMath.playSeconds(closure: .nan) == 1.2)
}

@Test func lidPollingFollowsWhatIsRenderingOrShown() {
    #expect(LidPollingPolicy.interval(enabled: true, previewing: false, angleObserved: false) == LidPollingPolicy.liveInterval)
    #expect(LidPollingPolicy.interval(enabled: false, previewing: true, angleObserved: false) == LidPollingPolicy.liveInterval)
    #expect(LidPollingPolicy.interval(enabled: false, previewing: false, angleObserved: true) == LidPollingPolicy.idleInterval)
    #expect(LidPollingPolicy.interval(enabled: false, previewing: false, angleObserved: false) == nil)
    #expect(LidPollingPolicy.liveInterval < LidPollingPolicy.idleInterval)
}

@Test func darkeningAndVeilCoverageMatchTheirContextForms() {
    for closure in [0.1, 0.35, 0.6, 0.9, 1.0] {
        let context = EffectContext(closure: closure, parameters: .init(strength: 0.7))
        for edge in [0.0, 0.3, 0.75, 1.0] {
            #expect(EffectMath.darkening(edge: edge, context: context) == EffectMath.darkening(edge: edge, coverage: context.motion * context.strength, finalFade: context.finalFade))
        }
    }
    #expect(EffectMath.veilCoverage(edge: 1, coverage: 0.5) == 0.5)
    #expect(EffectMath.veilCoverage(edge: 0, coverage: 0.5) == 0)
    #expect(EffectMath.veilCoverage(edge: 2, coverage: 0.5) == 0.5)
}
