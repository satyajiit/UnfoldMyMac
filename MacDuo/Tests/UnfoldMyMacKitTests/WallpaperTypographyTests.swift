import AppKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func wallpaperConnectionSheetsRenderInBothAppearances() throws {
    guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"] else { return }
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    UnfoldMyMacType.register()
    let suite = "wallpaper-sheet-test-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let setup = WallpaperSetupController(preferences: UserDefaultsPreferencesStore(defaults: defaults))
    let templates = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
    for scheme in [ColorScheme.light, .dark] {
        for id in ["github-after-hours", "codex-mission-control", "codex-foundry"] {
            let template = try #require(templates.first { $0.id == id })
            setup.open(template, applyAfterSetup: true)
            let request = try #require(setup.request)
            let renderer = ImageRenderer(content: WallpaperTemplateSetupSheet(setup: setup, request: request).environment(\.colorScheme, scheme)
                .background(scheme == .dark ? Color(hex: 0x16181D) : Color.white))
            let image = try #require(renderer.cgImage)
            #expect(image.width >= 500)
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path).appendingPathComponent(id + "-setup" + (scheme == .dark ? "-dark.png" : "-light.png")))
        }
    }
}

@Test @MainActor func everyWallpaperHeadlineRendersInsideItsReservedArea() throws {
    UnfoldMyMacType.register()
    let templates = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false).templates
    for original in templates {
        guard let headline = original.layers.first(where: { $0.id == "headline" && $0.height != nil }) else { continue }
        var phrases = headline.phrases ?? [headline.content]
        if original.id == "codex-mission-control" {
            phrases = CodexHookActivity.events.map {
                CodexActivityProvider.snapshot(records: [.init(session: "s", event: $0, timestamp: .now)], at: .now).text["activity.headline"]!
            }
        }
        for phrase in Set(phrases) {
            for (width, height) in [(1280, 800), (800, 500), (400, 640)] {
                var template = original, layer = headline
                layer.content = phrase; layer.phrases = nil; layer.binding = nil
                template.layers = [layer]
                let scale = min(Double(width)/1600, Double(height)/1000)
                let font = try #require(NSFont(name: "SpaceGrotesk-Bold", size: layer.size*1600*scale*0.5))
                for line in phrase.split(separator: "\n") {
                    #expect((String(line) as NSString).size(withAttributes: [.font: font]).width < 1600*scale*layer.width)
                }
                let content = WallpaperLayers(template: template, snapshot: .init(), animated: false)
                    .frame(width: CGFloat(width), height: CGFloat(height))
                let image = try #require(ImageRenderer(content: content).cgImage)
                var pixels = [UInt8](repeating: 0, count: width*height*4)
                let context = try #require(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                let occupied = (0..<height).filter { y in
                    (0..<width).contains { x in pixels[(y*width+x)*4+3] > 96 }
                }
                let top = (Double(height)-1000*scale)/2 + layer.y*1000*scale
                let bottom = top + (layer.height ?? 0)*1000*scale
                #expect(!occupied.isEmpty)
                #expect(Double(occupied.first ?? -100) >= top-3)
                #expect(Double(occupied.last ?? height) <= bottom+3)
                if let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"], phrase == "I HAVE\nA PATCH FOR THAT.", width == 1280 {
                    template = original
                    template.layers = original.layers.map { $0.id == layer.id ? layer : $0 }
                    let render = ImageRenderer(content: WallpaperLayers(template: template, snapshot: .init(), animated: false)
                        .frame(width: 1280, height: 800).background(Color(hex: template.background)))
                    let composed = try #require(render.cgImage)
                    let png = try #require(NSBitmapImageRep(cgImage: composed).representation(using: .png, properties: [:]))
                    try png.write(to: URL(fileURLWithPath: path).appendingPathComponent("codex-patch-typography.png"))
                }
            }
        }
    }
}
