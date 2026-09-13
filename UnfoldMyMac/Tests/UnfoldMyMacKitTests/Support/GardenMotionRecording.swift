import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Opt-in visual diagnostic: deterministic 60 Hz frames through the same input dynamics and smoother.
/// ffmpeg receives rendered BGRA pixels through a pipe; no desktop or microphone is captured.
@MainActor func renderGardenMotion(_ pipeline: WallpaperPipeline, directory: URL) throws {
    let process = Process(), pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pixel_format", "bgra",
                         "-video_size", "3024x1964", "-framerate", "60", "-i", "pipe:0", "-an",
                         "-c:v", "h264_videotoolbox", "-b:v", "18000000", "-pix_fmt", "yuv420p",
                         directory.appendingPathComponent("motion.mp4").path]
    process.standardInput = pipe
    try process.run()
    var dynamics = WallpaperInputDynamics(), smoother = WallpaperFrameSmoother(template: pipeline.template)
    for index in 0..<1320 {
        let t = Double(index)/60
        // Includes a reversed retreat before full closure, full closure, then antenna-first reopening.
        let angle = gardenRecordedAngle(at: t)
        if index.isMultiple(of: 2) {
            dynamics.sample(now: t, lidAngle: angle, rms: t > 8 && t < 8.3 ? 0.1 : 0,
                            sensitivity: 1, battery: 0.65, pluggedIn: t > 10,
                            daylight: 0.35, soundEnabled: true, reducedMotion: false)
        }
        smoother.targetLiveInputs = dynamics.value
        smoother.targetLiveInputs.parallax = SIMD2(sin(t*0.6)*0.9, cos(t*0.43)*0.6)
        smoother.targetLiveInputs.motionStir = t > 7 && t < 9 ? 0.6 : 0
        smoother.setTargets(energy: t > 10 ? 0.8 : 0.2, channels: .zero, grid: nil)
        var frame = smoother.advance(delta: 1.0/60, animating: true)
        frame.time += 18
        let rendered = try OffscreenRenderer.render(pipeline, frame: frame, width: 3024, height: 1964)
        try pipe.fileHandleForWriting.write(contentsOf: Data(rendered.pixels))
    }
    try pipe.fileHandleForWriting.close()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

private func gardenRecordedAngle(at time: Double) -> Double {
    switch time {
    case ..<3: 110
    case ..<3.5: 8
    case ..<4: 100
    case ..<6: 8
    default: 110
    }
}
