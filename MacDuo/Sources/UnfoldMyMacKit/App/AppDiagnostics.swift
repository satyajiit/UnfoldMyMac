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
    /// The compile units `script/compile_shaders.sh` precompiles, as JSON.
    static func printShaderUnits() {
        struct Unit: Encodable { let id: String; let family: String; let resources: [String]; let mathMode: String }
        let modules = ShaderModule.effects + WallpaperShaderCatalog().modules
        let units = modules.map { Unit(id: $0.id, family: $0.family.rawValue, resources: $0.resources, mathMode: $0.mathMode.rawValue) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(units), let text = String(data: data, encoding: .utf8) { print(text) }
    }

    private static func renderHashes(_ gpu: GPUContext) throws -> [String: String] {
        var hashes: [String: String] = [:]
        let size = 64
        let pose = EffectContext(closure: 0.5, time: 1.5)
        let frost = try FrostPipeline(gpu: gpu)
        frost.receive(try gradientFrame(size: size))
        hashes["frost"] = try OffscreenRenderer.render(frost, frame: pose, width: size, height: size).sha256
        hashes["curtains"] = try OffscreenRenderer.render(try CurtainsPipeline(gpu: gpu), frame: pose, width: size, height: size).sha256
        hashes["current"] = try OffscreenRenderer.render(try CurrentPipeline(gpu: gpu), frame: pose, width: size, height: size).sha256
        hashes["peekaboo"] = try OffscreenRenderer.render(try PeekabooPipeline(gpu: gpu), frame: pose, width: size, height: size).sha256
        for artwork in try LibraryAssets.artworks() {
            hashes["art/\(artwork.id.rawValue)"] = try OffscreenRenderer.render(try ArtRevealPipeline(artwork: artwork, gpu: gpu), frame: pose, width: size, height: size).sha256
        }
        let shaders = WallpaperShaderCatalog()
        for template in try WallpaperTemplateRegistry(shaders: shaders, loadUserTemplates: false).templates {
            let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: shaders)
            hashes["wallpaper/\(template.id)"] = try OffscreenRenderer.render(pipeline, frame: .cover, width: size, height: size).sha256
        }
        return hashes
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
