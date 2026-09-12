import AppKit
import Metal
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@MainActor struct WallpaperHarness {
    let pipeline: WallpaperPipeline
    func render(time: Double, energy: Double, width: Int = 640, height: Int = 400, channels: SIMD4<Float> = .zero, grid: WallpaperScalarGrid? = nil) throws -> (pixels: [UInt8], gpu: Double) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget]
        let texture = try #require(pipeline.catalog.gpu.makeTexture(descriptor: descriptor))
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture; pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        let command = try #require(pipeline.catalog.queue.makeCommandBuffer())
        #expect(pipeline.encode(command: command, pass: pass, size: CGSize(width: width,height: height), time: time, energy: energy, channels: channels, grid: grid))
        command.commit(); command.waitUntilCompleted(); #expect(command.error == nil)
        var bytes = [UInt8](repeating: 0, count: width*height*4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0) }
        return (bytes, command.gpuEndTime-command.gpuStartTime)
    }
}

@Test @MainActor func wallpaperTemplatesRenderReactAndStayWithinFrameBudget() throws {
    let catalog = try WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    #expect(registry.templates.count == 10 && registry.errors.isEmpty)
    for template in registry.templates {
        let pipeline = try WallpaperPipeline(template: template, catalog: catalog)
        let harness = WallpaperHarness(pipeline: pipeline)
        let initial = try harness.render(time: 2, energy: 0.2).pixels
        #expect(stride(from: 3, to: initial.count, by: 4).allSatisfy { initial[$0] == 255 })
        #expect(try harness.render(time: 2, energy: 0.2).pixels == initial)
        #expect(try harness.render(time: 5, energy: 0.2).pixels != initial)
        #expect(try harness.render(time: 2, energy: 0.9).pixels != initial)
        if template.shader == "pulse" || template.shader == "codex-foundry" {
            #expect(try harness.render(time: 2, energy: 0.2, channels: SIMD4(1,0,0,0)).pixels != initial)
        }
        let portrait = try harness.render(time: 2, energy: 0.5, width: 400, height: 640).pixels
        #expect(portrait.count == 400*640*4)
        var times: [Double] = []
        for i in 0..<10 {
            let result = try harness.render(time: Double(i)/60, energy: 0.5, width: 1920, height: 1200)
            if i > 1 { times.append(result.gpu) }
        }
        let median = times.sorted()[times.count/2]
        print(String(format: "Wallpaper %@ 1920×1200 GPU median %.2f ms", template.id, median*1000))
        #expect(median < 1.0/60)
        if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let image = try WallpaperThumbnailRenderer.image(pipeline: pipeline)
            let data = try #require(image.tiffRepresentation)
            try NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent(template.id + ".png"))
        }
    }
}

@Test @MainActor func wallpaperRegistryRejectsDuplicateUnknownShaderAndInvalidLayers() throws {
    let catalog = try WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    var template = try #require(registry.templates.first)
    #expect(throws: WallpaperError.duplicateID(template.id)) { try registry.register(template) }
    template.id = "extension-example"; template.shader = "missing"
    #expect(throws: WallpaperError.missingShader("missing")) { try registry.register(template) }
    template.shader = "pulse"; template.layers[0].size = .infinity
    #expect(throws: WallpaperError.invalidTemplate) { try registry.register(template) }
    template.layers[0].size = 0.01; template.layers[0].x = -1
    #expect(throws: WallpaperError.invalidTemplate) { try registry.register(template) }
}

@Test @MainActor func wallpaperDesktopHostStaysBelowIconsAndRestoresByClosing() {
    let host = WallpaperDesktopHost()
    host.show { SwiftUI.Color.black }
    #expect(host.windows.count == NSScreen.screens.count)
    for window in host.windows {
        let screen = window.screen!
        print("Wallpaper geometry: screen=\(screen.frame), window=\(window.frame), content=\(window.contentView!.frame), safe=\(window.contentView!.safeAreaInsets)")
        #expect(window.frame == screen.frame)
        #expect(window.level.rawValue > Int(CGWindowLevelForKey(.desktopWindow)))
        #expect(window.level.rawValue < Int(CGWindowLevelForKey(.desktopIconWindow)))
        #expect(window.ignoresMouseEvents && !window.canBecomeKey)
    }
    host.stop()
    #expect(host.windows.isEmpty)
}

@Test @MainActor func wallpaperRendererPausesAndReleasesDelegate() throws {
    let catalog = try WallpaperShaderCatalog()
    let template = try #require(WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates.first)
    let renderer = WallpaperMetalRenderer(pipeline: try WallpaperPipeline(template: template, catalog: catalog))
    renderer.configure(energy: 0.5, fps: 60)
    #expect(!renderer.isPaused && renderer.framesPerSecond == 60)
    renderer.configure(energy: 0.5, fps: 0)
    #expect(renderer.isPaused)
    renderer.stop()
    #expect(renderer.isPaused && renderer.view.onLayout == nil)
}
