import AppKit
import SwiftUI
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Deterministic inputs for the website's interactive controls. No device data is read.
@MainActor
extension RenderMedia {
    static func renderInteractiveScenes(registry: WallpaperTemplateRegistry, gpu: GPUContext,
                                        catalog: WallpaperShaderCatalog) throws {
        for template in registry.templates where ["hinge-garden", "the-workshop"].contains(template.id) {
            let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog, assets: registry.assets(for: template.id))
            for clip in ["idle-battery", "idle-charging", "connect", "disconnect", "lid-battery", "lid-charging"] {
                try renderSceneClip(template, clip: clip, pipeline: pipeline, gpu: gpu)
            }
        }
    }

    static func renderSceneClip(_ template: WallpaperTemplate, clip: String, pipeline: WallpaperPipeline, gpu: GPUContext) throws {
        let scrubbing = clip.hasPrefix("lid-")
        let count = scrubbing ? 103 : clip == "connect" ? 600 : 360
        var dynamics = WallpaperInputDynamics()
        var smoother = WallpaperFrameSmoother(template: template)
        let initialPower = clip == "idle-charging" || clip == "disconnect" || clip == "lid-charging"
        // Settle lighting and geometry before recording. A connection is a subsequent event.
        for frame in 0..<180 {
            _ = sceneSample(template, time: Double(frame) / fps, power: initialPower, dynamics: &dynamics, smoother: &smoother)
        }
        let directory = "interactive/\(template.id)-\(clip)"
        for index in 0..<count {
            try autoreleasepool {
                let elapsed = Double(index) / fps
                let power = clip == "connect" ? elapsed >= 0.1 : clip == "disconnect" ? elapsed < 0.1 : initialPower
                var frame = sceneSample(template, time: 3 + elapsed, power: power, dynamics: &dynamics, smoother: &smoother)
                if scrubbing {
                    frame.time = 21
                    frame.liveInputs.lidOpen = Double(index) / 102
                }
                let rendered = try gpuImage(gpu: gpu.device, queue: gpu.queue, format: .bgra8Unorm) { command, pass in
                    pipeline.encode(command: command, pass: pass, size: size, frame: frame)
                }
                try save(Image(nsImage: rendered).resizable().frame(width: size.width, height: size.height), directory: directory, frame: index, totalFrames: count)
                if scrubbing && (index == 0 || index == count - 1) {
                    let pose = index == 0 ? "closed" : "open"
                    let powerName = initialPower ? "charging" : "battery"
                    guard let image = rendered.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw CocoaError(.coderInvalidValue) }
                    try normalizedPNG(image).write(to: output.appendingPathComponent("interactive/\(template.id)-\(pose)-\(powerName).png"))
                }
            }
        }
        print("Exported interactive scene: \(template.id) / \(clip)")
    }

    static func sceneSample(_ template: WallpaperTemplate, time: Double, power: Bool,
                            dynamics: inout WallpaperInputDynamics, smoother: inout WallpaperFrameSmoother) -> WallpaperFrame {
        let workshop = template.id == "the-workshop"
        dynamics.sample(now: time, lidAngle: 110, rms: 0, sensitivity: 1,
                        battery: 0.8, pluggedIn: power, daylight: workshop ? 0.8 : 0.35,
                        soundEnabled: false, reducedMotion: false)
        smoother.targetLiveInputs = dynamics.value
        smoother.setTargets(energy: 0.3, channels: workshop ? SIMD4(8.0 / 12, 18.0 / 24, 1, 1) : .zero, grid: nil)
        var frame = smoother.advance(delta: 1 / fps, animating: true)
        frame.time += 18
        return frame
    }
}
