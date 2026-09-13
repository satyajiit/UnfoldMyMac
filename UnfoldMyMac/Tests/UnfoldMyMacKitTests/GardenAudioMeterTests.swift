import AVFoundation
import Testing
@testable import UnfoldMyMacKit

@Test @MainActor func gardenAudioTapCreatedOnMainActorRunsOnAudioServiceQueue() async throws {
    let meter = WallpaperAudioMeter()
    let tap = meter.makeTap()
    let amplitude: Double = try await withCheckedThrowingContinuation { continuation in
        DispatchQueue(label: "test.garden.audio-service").async {
            do {
                dispatchPrecondition(condition: .notOnQueue(.main))
                let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
                let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
                buffer.frameLength = 64
                let samples = try #require(buffer.floatChannelData?[0])
                for i in 0..<64 { samples[i] = i.isMultiple(of: 2) ? 0.2 : -0.2 }
                // Exercise the exact closure installed on AVAudioEngine, without microphone access.
                tap(buffer, AVAudioTime(sampleTime: 0, atRate: 48_000))
                continuation.resume(returning: meter.read(now: ProcessInfo.processInfo.systemUptime))
            } catch { continuation.resume(throwing: error) }
        }
    }
    #expect(abs(amplitude - 0.2) < 0.00001)
}

@Test func gardenAudioMeterRetainsBriefPeaksBetweenReadsAndDiscardsStaleSamples() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
    buffer.frameLength = 64
    let samples = try #require(buffer.floatChannelData?[0])
    let meter = WallpaperAudioMeter()
    for i in 0..<64 { samples[i] = i.isMultiple(of: 2) ? 0.2 : -0.2 }
    meter.receive(buffer, now: 0)
    for i in 0..<64 { samples[i] = 0.01 }
    meter.receive(buffer, now: 0.02)
    #expect(abs(meter.read(now: 0.033)-0.2) < 0.00001)
    #expect(meter.read(now: 0.04) == 0, "A peak is consumed once")
    meter.receive(buffer, now: 1)
    #expect(meter.read(now: 1.5) == 0)
    meter.receive(buffer, now: 2); meter.reset()
    #expect(meter.read(now: 2.01) == 0)
}
