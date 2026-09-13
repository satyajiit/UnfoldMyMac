// Website export adapted from the updated README preview exporter.
// Synthetic desktop and sample data only; native captures include only our two fixture windows.
import AppKit
import SwiftUI
import Metal
import MetalKit
import ScreenCaptureKit
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@main
@MainActor
struct RenderMedia {
    static let size = CGSize(width: 960, height: 600)
    nonisolated static let frames = 240
    static let fps = 60.0
    static let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    // Same synthetic oval as the native observatory tests; no live NOAA request.
    static let auroraGrid: WallpaperScalarGrid = {
        var values: [Float] = []
        for latitude in -90...90 {
            for longitude in 0..<360 {
                let center = 68 + 5 * sin(Double(longitude) * .pi / 180)
                values.append(Float(0.8 * exp(-pow((abs(Double(latitude)) - center) / 5, 2))))
            }
        }
        return .init(revision: "website-sample-oval-v1", width: 360, height: 181, values: values)
    }()

    static func main() async throws {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.accessory)
        UnfoldMyMacType.register()
        let gpu = try GPUContext()
        let catalog = WallpaperShaderCatalog()
        let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
        for template in registry.templates where CommandLine.arguments.count < 3 || template.id == CommandLine.arguments[2] {
            try renderWallpaper(template, gpu: gpu, catalog: catalog)
        }

        var effects: [(String, any EffectPipeline)] = [
            ("curtains", try CurtainsPipeline(gpu: gpu)),
            ("current", try CurrentPipeline(gpu: gpu)),
            ("peekaboo", try PeekabooPipeline(gpu: gpu))
        ]
        for artwork in try EffectAssets.artworks() {
            effects.append((artwork.id.rawValue, try ArtRevealPipeline(artwork: artwork, gpu: gpu)))
        }
        let desktopRenderer = ImageRenderer(content: DesktopFixture())
        desktopRenderer.scale = 0.75
        guard let desktopCG = desktopRenderer.cgImage else { throw CocoaError(.coderInvalidValue) }
        let desktopImage = NSImage(cgImage: desktopCG, size: size)
        let backdrop = Image(nsImage: desktopImage).resizable().frame(width: size.width, height: size.height)
        try save(backdrop, directory: "desktop", frame: 0)
        for (name, pipeline) in effects where selected(name) {
            for frame in 0..<frames {
                try autoreleasepool {
                    let context = effectContext(frame)
                    let foreground = try gpuImage(gpu: gpu.device, queue: gpu.queue, format: pipeline.surface.pixelFormat) { command, pass in
                        pipeline.encode(command: command, pass: pass, size: size, context: context)
                    }
                    let scene = ZStack {
                        backdrop
                        Image(nsImage: foreground).resizable()
                    }.frame(width: size.width, height: size.height)
                    try save(scene, directory: "effects/" + name, frame: frame)
                }
            }
            print("Exported effect: " + name)
        }
        if selected("frost") {
            let pipeline = try FrostPipeline(gpu: gpu)
            let source = try frostSource(desktopCG, gpu: gpu.device)
            for frame in 0..<frames {
                try autoreleasepool {
                    let rendered = try gpuImage(gpu: gpu.device, queue: gpu.queue, format: .bgra8Unorm_srgb) { command, pass in
                        pipeline.encode(command: command, source: source, pass: pass, context: effectContext(frame))
                    }
                    try save(Image(nsImage: rendered).resizable().frame(width: size.width, height: size.height), directory: "effects/frost", frame: frame)
                }
            }
            print("Exported effect: frost")
        }
        if selected("veil") || selected("fade") {
            try await nativeEffects(desktopImage: desktopImage)
        }
    }

    static func renderWallpaper(_ template: WallpaperTemplate, gpu: GPUContext, catalog: WallpaperShaderCatalog) throws {
        let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
        let frameCount = template.id == "hinge-garden" ? 1320 : frames
        var dynamics = WallpaperInputDynamics()
        var smoother = WallpaperFrameSmoother(template: template)
        for frame in 0..<frameCount {
            try autoreleasepool {
                let time = Double(frame) / fps
                var snapshot = demoSnapshot(time: time)
                if let countdown = template.countdown {
                    // Freeze the recording's calendar date so exports remain reproducible.
                    let date = ISO8601DateFormatter().date(from: "2026-09-12T12:00:00Z")!
                    var sample = countdown.sample(at: date, timeZone: TimeZone(secondsFromGMT: 0)!)
                    sample.timestamp = .now
                    snapshot.sources["countdown"] = sample
                }
                var channels = SIMD4<Float>.zero
                for (index, binding) in (template.channels ?? []).prefix(4).enumerated() {
                    channels[index] = Float(min(1, max(0, (snapshot.number(binding.metric) ?? 0) / binding.scale)))
                }
                let energy = (snapshot.number(template.reactiveMetric) ?? 0) / template.reactiveScale
                let renderedFrame = template.id == "hinge-garden"
                    ? gardenFrame(time, dynamics: &dynamics, smoother: &smoother)
                    : WallpaperFrame(time: 4 + time, energy: energy, channels: channels, grid: template.gridBinding.flatMap { snapshot.grid($0) })
                let background = try gpuImage(gpu: gpu.device, queue: gpu.queue, format: .bgra8Unorm) { command, pass in
                    pipeline.encode(command: command, pass: pass, size: size, frame: renderedFrame)
                }
                let scene = ZStack {
                    Image(nsImage: background).resizable()
                    WallpaperLayers(template: template, snapshot: snapshot, animated: false)
                }.frame(width: size.width, height: size.height)
                try save(scene, directory: "wallpapers/" + template.id, frame: frame, totalFrames: frameCount)
            }
        }
        print("Exported wallpaper: " + template.id)
    }

    // Synthetic inputs follow the same dynamics and smoother as the native scene. No sensors are read.
    static func gardenFrame(_ time: Double, dynamics: inout WallpaperInputDynamics,
                            smoother: inout WallpaperFrameSmoother) -> WallpaperFrame {
        let angle = time < 3 || time >= 6 ? 110.0 : 8.0
        dynamics.sample(now: time, lidAngle: angle, rms: time > 8 && time < 8.3 ? 0.1 : 0,
                        sensitivity: 1, battery: 0.65, pluggedIn: time > 10,
                        daylight: 0.35, soundEnabled: true, reducedMotion: false)
        smoother.targetLiveInputs = dynamics.value
        smoother.targetLiveInputs.parallax = SIMD2(sin(time * 0.6) * 0.9, cos(time * 0.43) * 0.6)
        smoother.targetLiveInputs.motionStir = time > 7 && time < 9 ? 0.6 : 0
        smoother.setTargets(energy: time > 10 ? 0.8 : 0.2, channels: .zero, grid: nil)
        var frame = smoother.advance(delta: 1 / fps, animating: true)
        frame.time += 18
        return frame
    }

    static func selected(_ name: String) -> Bool {
        CommandLine.arguments.count < 3 || CommandLine.arguments[2] == "effects" || CommandLine.arguments[2] == name
    }

    static func frostSource(_ image: CGImage, gpu: MTLDevice) throws -> MTLTexture {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else { throw CocoaError(.coderInvalidValue) }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]; descriptor.storageMode = .shared
        guard let texture = gpu.makeTexture(descriptor: descriptor) else { throw CocoaError(.coderInvalidValue) }
        bytes.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        return texture
    }

    static func effectContext(_ frame: Int) -> EffectContext {
        let raw = (1 - cos(2 * Double.pi * Double(frame) / Double(frames))) / 2
        return EffectContext(closure: EffectMath.calibratedClosure(raw, completionFraction: 0.8), time: Double(frame) / fps)
    }

    static func nativeEffects(desktopImage: NSImage) async throws {
        guard CGPreflightScreenCaptureAccess(), let screen = NSScreen.main else {
            throw NSError(domain: "READMEPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Native material export needs existing screen capture access."])
        }
        let rect = CGRect(x: screen.frame.minX + 90, y: screen.frame.minY + 90, width: size.width, height: size.height)
        let background = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        background.isReleasedWhenClosed = false; background.hasShadow = false
        background.level = .floating; background.ignoresMouseEvents = true
        let imageView = NSImageView(frame: CGRect(origin: .zero, size: size))
        imageView.image = desktopImage; imageView.imageScaling = .scaleAxesIndependently
        background.contentView = imageView
        let overlay = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        overlay.isReleasedWhenClosed = false; overlay.hasShadow = false
        overlay.isOpaque = false; overlay.backgroundColor = .clear
        overlay.level = .floating; overlay.ignoresMouseEvents = true
        overlay.appearance = NSAppearance(named: .aqua)
        background.orderFrontRegardless()
        overlay.orderFrontRegardless()
        defer { overlay.orderOut(nil); background.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(300))
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let windowIDs = Set([CGWindowID(background.windowNumber), CGWindowID(overlay.windowNumber)])
        let windows = content.windows.filter { windowIDs.contains($0.windowID) }
        guard windows.count == 2,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32,
              let display = content.displays.first(where: { $0.displayID == displayID }) else { throw CocoaError(.coderInvalidValue) }
        let filter = SCContentFilter(display: display, including: windows)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(size.width); configuration.height = Int(size.height)
        configuration.sourceRect = CGRect(x: rect.minX - screen.frame.minX, y: screen.frame.maxY - rect.maxY, width: size.width, height: size.height)
        configuration.showsCursor = false; configuration.ignoreShadowsDisplay = true
        configuration.ignoreGlobalClipDisplay = true
        configuration.captureResolution = .best
        for (name, kind) in [("veil", NativeEffectRenderer.Kind.veil), ("fade", .fade)] where selected(name) {
            let renderer = NativeEffectRenderer(kind: kind)
            renderer.prepare(size: size, scale: screen.backingScaleFactor)
            overlay.contentView = renderer.view
            for frame in 0..<frames {
                renderer.update(effectContext(frame))
                renderer.view.displayIfNeeded()
                CATransaction.flush()
                try await Task.sleep(for: .milliseconds(85))
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                try writeFrame(normalizedPNG(image), directory: "effects/" + name, frame: frame)
            }
            renderer.stop()
            print("Exported effect: " + name)
        }
    }

    static func gpuImage(gpu: MTLDevice, queue: MTLCommandQueue, format: MTLPixelFormat,
                         encode: (MTLCommandBuffer, MTLRenderPassDescriptor) -> Bool) throws -> NSImage {
        let width = Int(size.width), height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]; descriptor.storageMode = .shared
        guard let texture = gpu.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer() else {
            throw CocoaError(.coderInvalidValue)
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        guard encode(command, pass) else { throw CocoaError(.coderInvalidValue) }
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: space,
                                  bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw CocoaError(.coderInvalidValue)
        }
        return NSImage(cgImage: image, size: size)
    }

    static func save<V: View>(_ scene: V, directory: String, frame: Int, totalFrames: Int = frames) throws {
        let renderer = ImageRenderer(content: scene)
        renderer.scale = 1
        guard let image = renderer.cgImage else {
            throw CocoaError(.coderInvalidValue)
        }
        try writeFrame(normalizedPNG(image), directory: directory, frame: frame, totalFrames: totalFrames)
    }

    static var encoder: Process?
    static var input: FileHandle?

    static func writeFrame(_ png: Data, directory: String, frame: Int, totalFrames: Int = frames) throws {
        if directory == "desktop" {
            try png.write(to: output.appendingPathComponent("demo-desktop.png"))
            return
        }
        let rawID = directory.split(separator: "/").last.map(String.init)!
        let id = rawID == "grok-event-horizon" ? "grok-horizon" : rawID
        if frame == 0 {
            let process = Process(), pipe = Pipe()
            guard let ffmpeg = ProcessInfo.processInfo.environment["WEBSITE_FFMPEG"] else { throw CocoaError(.fileReadNoSuchFile) }
            process.executableURL = URL(fileURLWithPath: ffmpeg)
            process.arguments = ["-v", "error", "-y", "-f", "image2pipe", "-framerate", "60", "-i", "pipe:0", "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "21", "-pix_fmt", "yuv420p", "-movflags", "+faststart", output.appendingPathComponent(id + ".mp4").path]
            process.standardInput = pipe
            try process.run()
            encoder = process; input = pipe.fileHandleForWriting
        }
        try input!.write(contentsOf: png)
        if frame == totalFrames - 1 {
            try input!.close()
            encoder!.waitUntilExit()
            guard encoder!.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
            encoder = nil; input = nil
        }
    }

    // SwiftUI switches between 16-bit wide-gamut and 8-bit images when an overlay
    // fully covers the desktop. A stable sRGB format keeps GIF palette generation
    // from resetting and dropping the beginning of the animation.
    static func normalizedPNG(_ image: CGImage) throws -> Data {
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.coderInvalidValue) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let normalized = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: normalized).representation(using: .png, properties: [:]) else { throw CocoaError(.coderInvalidValue) }
        return data
    }

    static func demoSnapshot(time: Double) -> WallpaperSnapshot {
        var snapshot = WallpaperSnapshot()
        let wave = (1 + sin(time * .pi / 2)) / 2
        snapshot.sources["mac"] = .init(timestamp: .now,
            numbers: ["mac.cpu": 24 + 35 * wave, "mac.memory": 42, "mac.memoryGB": 13.4, "mac.battery": 82],
            text: ["mac.status": "ROOM TO THINK.", "mac.power": "PLUGGED IN. ZONED OUT."])
        snapshot.sources["claude"] = .init(timestamp: .now,
            numbers: ["claude.sessions": 12, "claude.tokens": 82400 + floor(time) * 1200, "claude.energy": 0.35 + 0.35 * wave],
            text: ["claude.status": "SOMETHING'S COOKING.", "claude.scope": "LOCAL SESSION METADATA"])
        snapshot.sources["codex"] = .init(timestamp: .now,
            numbers: ["codex.sessions": 42, "codex.tokens": 128400 + floor(time) * 1800, "codex.recent": 4, "codex.energy": 0.5 + 0.3 * wave],
            text: ["codex.activity": "SOMETHING'S COOKING.", "codex.scope": "LOCAL HISTORY · NOT BILLING"])
        snapshot.sources["scene"] = .init(timestamp: .now,
            numbers: ["scene.remarks": 23, "scene.minutes": 3, "scene.laps": 12, "scene.energy": 0.55],
            text: ["scene.scope": "WALLPAPER SESSION · JUST FOR FUN"])
        snapshot.sources["github"] = .init(timestamp: .now,
            numbers: ["github.repos": 42, "github.followers": 128, "github.pushes": 7, "github.crowd": 0.5, "github.energy": 0.45],
            text: ["github.handle": "@YOURHANDLE", "github.status": "THE PUSH-UPS ARE PAYING OFF.", "github.scope": "PUBLIC PROFILE · SAMPLE DATA"])
        snapshot.sources["activity"] = .init(timestamp: .now,
            numbers: ["activity.turns": 42, "activity.tools": 168 + floor(time), "activity.energy": 0.95, "activity.state": 0.2, "activity.working": 2],
            text: ["activity.headline": "LET ME\nCOOK.", "activity.status": "WORKING · HANDS OFF THE SPATULA.", "activity.scope": "LOCAL LIFECYCLE HOOKS"])
        snapshot.sources["tool"] = .init(timestamp: .now,
            numbers: ["tool.value": 40 + 35 * wave],
            text: ["tool.label": "ONE MORE\nGOOD IDEA.", "tool.status": "FAMOUS LAST WORDS."])
        snapshot.sources["aurora"] = .init(timestamp: .now,
            numbers: ["aurora.kp": 3, "aurora.energy": 3.0 / 9],
            text: ["aurora.headline": "The atmosphere\nhas plans tonight.", "aurora.kpLabel": "Planetary Kp",
                   "aurora.reading": "3.0", "aurora.condition": "Unsettled", "aurora.forecast": "Sample forecast · Preview data"],
            grids: ["aurora.oval": auroraGrid])
        return snapshot
    }
}
