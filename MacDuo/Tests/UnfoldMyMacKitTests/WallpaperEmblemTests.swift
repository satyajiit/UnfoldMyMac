import AppKit
import CryptoKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test @MainActor func wallpaperOriginalMarksSurviveBackgroundChangesAndRejectInvalidPlacement() throws {
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    let originals = ["GTAVI": "f1a4e777835a98fa0386106ef5a948e8fd590121ee0cd72daa191997ed979616", "F1": "1fdcb92bab1a08d50bdf784fcf59d4c32da72cbce70cf941da9a509a257dfe2d",
                     "Codex": "69fb4384e161be8a20dcb94a9ac34aea4fbfaeb67514110a71e7b0732eccb0fc",
                     "Grok": "3a462c3c2524733c173bb05c431de737812f8219db8fa115b0025d12a347e086"]
    for template in registry.templates where template.emblem != nil {
        let mark = try #require(template.emblem)
        let url = try #require(WallpaperEmblemPipeline.url(mark.asset))
        let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        #expect(digest == originals[mark.asset])
        let original = try WallpaperHarness(pipeline: WallpaperPipeline(template: template, gpu: gpu, shaders: catalog))
            .render(time: 4, energy: 0.35).pixels
        let alternate = try WallpaperHarness(pipeline: WallpaperPipeline(template: template, gpu: gpu, shaders: catalog, imageURL: url))
            .render(time: 4, energy: 0.35).pixels
        if template.image == nil { #expect(original == alternate) }
        else {
            // Image-backed scenes may change behind the mark; opaque logo texels may not.
            let originalMark = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
            let markX = Int(mark.x * 640), markY = Int(mark.y * 400)
            let width = Int(mark.width * 640)
            let height = Int(Double(width) * Double(originalMark.pixelsHigh) / Double(originalMark.pixelsWide))
            var checked = 0
            for y in 2..<height-2 { for x in 2..<width-2 {
                let px = x * originalMark.pixelsWide / width, py = y * originalMark.pixelsHigh / height
                guard originalMark.colorAt(x: px, y: py)?.alphaComponent == 1 else { continue }
                let i = ((markY+y) * 640 + markX+x) * 4
                if original[i..<i+4] == alternate[i..<i+4] { checked += 1 }
            } }
            #expect(checked > width * height / 4)
            if mark.asset == "GTAVI" {
                var unmarked = template; unmarked.emblem = nil
                let background = try WallpaperHarness(pipeline: WallpaperPipeline(template: unmarked, gpu: gpu, shaders: catalog)).render(time: 4, energy: 0.35).pixels
                let corner = ((markY + height/2) * 640 + markX + width - 2) * 4
                #expect(original[corner..<corner+4] == background[corner..<corner+4])
            }
        }
        var invalid = template
        invalid.id = "invalid-mark"
        invalid.emblem?.asset = "../Codex"
        #expect(throws: WallpaperError.invalidTemplate) { try invalid.validated() }
        invalid.emblem = mark; invalid.emblem?.y = 0.99
        #expect(throws: WallpaperError.invalidTemplate) { try WallpaperPipeline(template: invalid, gpu: gpu, shaders: catalog) }
        invalid.emblem = mark; invalid.emblem?.asset = "MissingMark"
        #expect(throws: (any Error).self) { try registry.register(invalid) }
    }
}

@Test @MainActor func newWallpapersRespondToToolSignalsAndRenderCompleteCompositions() throws {
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    UnfoldMyMacType.register()
    for template in registry.templates {
        let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
        let harness = WallpaperHarness(pipeline: pipeline)
        let idle = try harness.render(time: 4, energy: 0.35).pixels
        let signal = try harness.render(time: 4, energy: 0.35, channels: SIMD4(0, 1, 0, 0)).pixels
        if ["codex-foundry", "grok-horizon"].contains(template.id) { #expect(idle != signal) }
        let portrait = try harness.render(time: 4, energy: 0.35, width: 400, height: 640).pixels
        #expect(stride(from: 3, to: portrait.count, by: 4).allSatisfy { portrait[$0] == 255 })
        guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"] else { continue }
        let pixels = try harness.render(time: 4, energy: 0.35, width: 1280, height: 800).pixels
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try #require(CGImage(width: 1280, height: 800, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 1280 * 4, space: space,
            bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent))
        let background = NSImage(cgImage: image, size: CGSize(width: 1280, height: 800))
        var snapshot = WallpaperSnapshot()
        snapshot.sources["codex"] = .init(timestamp: .now,
            numbers: ["codex.sessions": 42, "codex.tokens": 128_400],
            text: ["codex.activity": "SOMETHING'S COOKING.", "codex.scope": "LOCAL CODEX HISTORY · NOT BILLING"])
        snapshot.sources["scene"] = .init(timestamp: .now,
            numbers: ["scene.remarks": 23, "scene.minutes": 3, "scene.laps": 12],
            text: ["scene.scope": "WALLPAPER SESSION · JUST FOR FUN"])
        snapshot.sources["github"] = .init(timestamp: .now, numbers: ["github.repos": 96, "github.followers": 1234, "github.pushes": 17], text: ["github.handle": "@satyajiit", "github.status": "THE PUSH-UPS ARE PAYING OFF."])
        snapshot.sources["activity"] = .init(timestamp: .now, numbers: ["activity.turns": 42, "activity.tools": 168], text: ["activity.headline": "LET ME\nCOOK.", "activity.status": "WORKING · HANDS OFF THE SPATULA.", "activity.scope": "LOCAL HOOK HISTORY · STATES EXPIRE AFTER 5 MIN"])
        let composed = ZStack {
            Image(nsImage: background).resizable()
            WallpaperLayers(template: template, snapshot: snapshot, animated: false)
        }.frame(width: 1280, height: 800)
        let renderer = ImageRenderer(content: composed)
        let cgImage = try #require(renderer.cgImage)
        let png = try #require(NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]))
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(template.id + "-composition.png"))
    }
}
