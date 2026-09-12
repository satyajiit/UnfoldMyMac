import AppKit
import CoreVideo
import Foundation
import UnfoldMyMacCore

/// Command-line checks the build script and contributors run against the packaged app.
@MainActor enum AppDiagnostics {
    static func probe() -> Bool {
        let sensor = LidSensor(); print(sensor.diagnostic)
        return sensor.read() != nil
    }
    /// Compiles every shader unit from source and, when the bundle carries precompiled units, through them
    /// too, then renders each pipeline both ways at 64×64 and requires identical pixels.
    static func checkShader() -> Bool {
        do {
            let source = try GPUContext(libraryPolicy: .sourceOnly)
            let fromSource = try renderHashes(source)
            let bundled = try GPUContext(libraryPolicy: .preferPrecompiled)
            let fromBundle = try renderHashes(bundled)
            let mismatched = fromSource.keys.sorted().filter { fromSource[$0] != fromBundle[$0] }
            let precompiled = bundled.libraries.loadedPrecompiled
            print("\(source.libraries.compiledFromSource) shader units compiled from source, \(fromSource.count) pipelines rendered; " +
                  (precompiled > 0 ? "\(precompiled) precompiled units loaded, \(mismatched.isEmpty ? "all renders identical" : "MISMATCH: \(mismatched)")" : "no precompiled units in this bundle"))
            for (unit, problem) in bundled.libraries.precompiledProblems.sorted(by: { $0.key < $1.key }).prefix(3) { print("  precompiled \(unit): \(problem)") }
            return mismatched.isEmpty
        } catch { print(error.localizedDescription); return false }
    }
    /// The compile units `script/compile_shaders.sh` precompiles, as JSON; files are bundle-relative.
    static func printShaderUnits() {
        struct Unit: Encodable { let id: String; let files: [String]; let mathMode: String }
        let shaders = WallpaperShaderCatalog()
        _ = try? WallpaperTemplateRegistry(shaders: shaders, loadUserTemplates: false)
        let modules = ShaderModule.effects + shaders.modules
        let units = modules.map { Unit(id: $0.id, files: $0.resources.map(\.bundlePath), mathMode: $0.mathMode.rawValue) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(units), let text = String(data: data, encoding: .utf8) { print(text) }
    }

    /// Every registered GPU effect and every bundled scene, so a catalog entry no code can render fails the check.
    private static func renderHashes(_ gpu: GPUContext) throws -> [String: String] {
        var hashes: [String: String] = [:]
        let size = 64
        let pose = EffectContext(closure: 0.5, time: 1.5)
        let registry = EffectRegistry.builtIn()
        if let problem = registry.catalogError ?? registry.diagnostics.first { throw GPUError.allocationFailed("the effect catalog: \(problem)") }
        for entry in registry.entries {
            guard let makePipeline = entry.makePipeline else { continue }
            let pipeline = try makePipeline(gpu)
            if let sink = pipeline as? any DesktopFrameSink { sink.receive(try gradientFrame(size: size)) }
            hashes["effect/\(entry.descriptor.id.rawValue)"] = try render(pipeline, frame: pose, size: size)
        }
        let shaders = WallpaperShaderCatalog()
        let templates = try WallpaperTemplateRegistry(shaders: shaders, loadUserTemplates: false)
        if let problem = templates.errors.first { throw GPUError.allocationFailed("the wallpaper collection: \(problem)") }
        for template in templates.templates {
            let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: shaders, assets: templates.assets(for: template.id))
            hashes["wallpaper/\(template.id)"] = try OffscreenRenderer.render(pipeline, frame: WallpaperFrame(pose: template.coverPose), width: size, height: size).sha256
        }
        return hashes
    }
    private static func render(_ pipeline: some EffectPipeline, frame: EffectContext, size: Int) throws -> String {
        try OffscreenRenderer.render(pipeline, frame: frame, width: size, height: size).sha256
    }
    /// A deterministic capture frame, so Frost exercises its real texture path.
    private static func gradientFrame(size: Int) throws -> DesktopFrame {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        guard CVPixelBufferCreate(nil, size, size, kCVPixelFormatType_32BGRA, attributes, &buffer) == kCVReturnSuccess, let buffer else {
            throw GPUError.allocationFailed("a capture buffer")
        }
        CVPixelBufferLockBaseAddress(buffer, []); defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw GPUError.allocationFailed("a capture buffer") }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<size { for x in 0..<size {
            let pixel = base.advanced(by: y * stride + x * 4).assumingMemoryBound(to: UInt8.self)
            pixel[0] = UInt8(x * 4 % 256); pixel[1] = UInt8(y * 4 % 256); pixel[2] = UInt8((x + y) * 2 % 256); pixel[3] = 255
        } }
        return DesktopFrame(buffer)
    }
}
