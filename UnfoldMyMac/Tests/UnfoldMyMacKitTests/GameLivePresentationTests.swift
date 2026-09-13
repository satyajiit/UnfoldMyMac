import AppKit
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Deterministic example readings for visual review only; never bundled as live user data.
func gamePresentationSnapshot(at date: Date) -> WallpaperSnapshot {
    var snapshot = WallpaperSnapshot()
    snapshot.sources["power"] = PowerWallpaperProvider.snapshot(level: 0.72, charging: true, plugged: true, minutes: 38, lowPower: false, at: date)
    snapshot.sources["network"] = .init(timestamp: date, numbers: ["network.down": 4.2, "network.up": 0.8],
        text: ["network.download": "4.2 MB/s", "network.upload": "↑ 800 KB/s", "network.state": "↓ INBOUND · LIVE TRAFFIC"])
    snapshot.sources["thermal"] = ThermalWallpaperProvider.snapshot(.fair, at: date)
    snapshot.sources["mac"] = .init(timestamp: date, numbers: ["mac.cpu": 32, "mac.memory": 65])
    snapshot.sources["storage"] = StorageWallpaperProvider.snapshot(free: 183_000_000_000, total: 1_000_000_000_000, at: date)
    for (mode, minutes) in [(WallpaperRestClock.Mode.focus, 25.0), (.eyes, 20.0)] {
        var clock = WallpaperRestClock(mode: mode, minutes: minutes)
        clock.tick(uptime: 0, idle: 0)
        for time in 1...421 { clock.tick(uptime: Double(time), idle: 0) }
        snapshot.sources[mode.rawValue] = RestWallpaperProvider.snapshot(clock, idle: 0, at: date)
    }
    let reading = PublicWallpaperReading(value: gameWeatherFixture(at: date), fetched: date, cached: false)
    snapshot.sources["weather"] = WeatherWallpaperProvider.snapshot(reading,
        location: .init(id: 1, name: "Kyoto", latitude: 35, longitude: 135), at: date)
    snapshot.sources["wukong"] = .init(timestamp: date, numbers: ["wukong.players": 27_153, "wukong.crowd": 0.74],
        text: ["wukong.scope": "STEAM PLAYERS WORLDWIDE", "wukong.news": "Black Myth: Wukong — Community update",
               "wukong.newsDate": "Publisher update · Sep 13, 2026", "wukong.source": "Steam · example reading"])
    return snapshot
}

@Test(.requiresGPU, .tags(.gpu), arguments: gameWallpaperIDs)
@MainActor func gameLiveReadoutsRenderWithTheirDataAndExportReviewImages(_ id: String) throws {
    let shaders = WallpaperShaderCatalog()
    let registry = try WallpaperTemplateRegistry(shaders: shaders, loadUserTemplates: false)
    let template = try #require(registry.templates.first { $0.id == id })
    let date = Date.now
    let snapshot = gamePresentationSnapshot(at: date)
    let value = try #require(template.layers.first { $0.id == "value" })
    #expect(value.value(in: snapshot, at: date) != "—")
    #expect(value.value(in: snapshot, at: date.addingTimeInterval(16)) == value.content || value.format != .text)
    guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_GAME_LIVE_ARTIFACTS"] else { return }
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    UnfoldMyMacType.register()
    let pipeline = try WallpaperPipeline(template: template, gpu: TestGPU.context(), shaders: shaders, assets: registry.assets(for: id))
    let pose = WallpaperPose(template: template, snapshot: snapshot, at: date)
    let frame = WallpaperFrame(time: 4, energy: pose.energy, channels: pose.channels)
    let art = try OffscreenRenderer.cgImage(OffscreenRenderer.render(pipeline, frame: frame, width: 1440, height: 900))
    for (suffix, displaySnapshot) in [("", snapshot), ("-cover", WallpaperSnapshot())] {
        let view = ZStack {
            Image(decorative: art, scale: 1).resizable()
            WallpaperLayers(template: template, snapshot: displaySnapshot, animated: false)
        }.frame(width: 1440, height: 900)
        let renderer = ImageRenderer(content: view)
        let image = try #require(renderer.cgImage)
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path).appendingPathComponent(id + suffix + ".png"))
    }
}
