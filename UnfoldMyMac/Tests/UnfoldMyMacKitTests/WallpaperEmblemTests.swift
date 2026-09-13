import AppKit
import CryptoKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test(.requiresGPU, .tags(.gpu)) @MainActor func wallpaperOriginalMarksSurviveBackgroundChangesAndRejectInvalidPlacement() throws {
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let registry = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false)
    let originals = [
                     "GameWolverine": "7b8b0d8fef8c18c624599d346ecfa6068dd9e8572a401db4a6da432268b22759",
                     "GameCyberpunk": "4e37537b920d1d777b4182aa1814f729f170e04de49e4d62652046a34b4dce98",
                     "GameEldenRing": "5a289d0179106e0887be0b11f8c08cf8c706aef506b67dec2ee1db9ec439a340",
                     "GameDoom": "94ed3a0c6eb07bd8268bf3c259991c94e28335389582c59539460290a4c85266",
                     "GameForza": "fcf67c7e3e1e1bf4975bcdd7b75a4665969796b75adea4874bb36dee278baf6a",
                     "GameHollowKnight": "7704292de9a6ef4be40e4602e89ce91954d1ee755c23461e1892f187b63c95ea",
                     "GameWukong": "b5c77c787543e456ea7519f44d1b7d8cad42aef9f800240ccfc6625f108c0977",
                     "GameRedDead": "d35231dd831ed86713c4b6a2015cd76336f873ed55115ab14db8652526586892",
                     "GameBaldursGate": "b9e651597eed8c36d0546fd1bc9b6f84e9ddd6ce08dff990f7d298b7de8594d8",
                     "GameGhostTsushima": "5efedfa4e52d1c591568b4f157bb31e70f6e3110a60cab17ddcfe2de86bc5c97",
                     "GTAVI": "f1a4e777835a98fa0386106ef5a948e8fd590121ee0cd72daa191997ed979616", "F1": "1fdcb92bab1a08d50bdf784fcf59d4c32da72cbce70cf941da9a509a257dfe2d",
                     "Codex": "69fb4384e161be8a20dcb94a9ac34aea4fbfaeb67514110a71e7b0732eccb0fc",
                     "Grok": "3a462c3c2524733c173bb05c431de737812f8219db8fa115b0025d12a347e086"]
    for template in registry.templates where template.emblem != nil {
        let mark = try #require(template.emblem)
        let url = try #require(registry.assets(for: template.id).mark(mark.asset))
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
            let emblem = try WallpaperEmblemPipeline(placement: mark, canvas: template.canvasSize, gpu: gpu)
            let mask = try OffscreenHarness.render(device: gpu.device, queue: gpu.queue, pixelFormat: .bgra8Unorm,
                width: 640, height: 400) { command, pass in
                guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
                emblem.encode(encoder, size: CGSize(width: 640, height: 400))
                encoder.endEncoding(); return true
            }.pixels
            // Test actual sampled opacity, so transparent padding and fine wordmarks
            // cannot invalidate the test's coverage assumption. UNorm rounding gets 2 levels.
            let opaque = stride(from: 0, to: mask.count, by: 4).filter { mask[$0 + 3] >= 254 }
            #expect(!opaque.isEmpty, "The original mark must have visible ink: \(mark.asset)")
            #expect(opaque.allSatisfy { i in
                (0..<3).allSatisfy { abs(Int(original[i + $0]) - Int(alternate[i + $0])) <= 2 }
            }, "Opaque pixels of \(mark.asset) must survive a background change")
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
        #expect(throws: WallpaperError.invalidField("emblem")) { try invalid.validated() }
        invalid.emblem = mark; invalid.emblem?.y = 0.99
        #expect(throws: WallpaperError.invalidField("emblem")) { try WallpaperPipeline(template: invalid, gpu: gpu, shaders: catalog) }
        invalid.emblem = mark; invalid.emblem?.asset = "MissingMark"
        #expect(throws: WallpaperError.missingAsset("MissingMark")) { try registry.register(invalid) }
    }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func newWallpapersRespondToToolSignalsAndRenderCompleteCompositions() throws {
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
