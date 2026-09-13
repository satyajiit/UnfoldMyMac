import AppKit
import Metal
import SwiftUI
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

private func forecastFixture(at date: Date, badCoordinate: Bool = false) throws -> Data {
    var coordinates: [[Double]] = []
    for lon in 0..<360 { for lat in -90...90 {
        let center = 68 + 5 * sin(Double(lon) * .pi / 180)
        let strength = 80 * exp(-pow((abs(Double(lat)) - center) / 5, 2))
        coordinates.append([Double(lon), Double(lat), strength.rounded()])
    } }
    if badCoordinate { coordinates[0][0] = 999 }
    return try JSONSerialization.data(withJSONObject: ["Observation Time": date.ISO8601Format(),
        "Forecast Time": date.addingTimeInterval(3600).ISO8601Format(), "coordinates": coordinates], options: [.sortedKeys])
}

@Test func countdownUsesCalendarDaysAcrossDSTTimeZonesAndReleaseBoundaries() throws {
    let countdown = WallpaperCountdown(year: 2026, month: 11, day: 19, sourceURL: URL(string: "https://www.rockstargames.com/VI")!)
    let utc = TimeZone(secondsFromGMT: 0)!, la = TimeZone(identifier: "America/Los_Angeles")!, india = TimeZone(identifier: "Asia/Kolkata")!
    let date = try #require(NOAAWeatherClient.date("2026-11-18T20:00:00Z"))
    #expect(countdown.remainingDays(at: date, timeZone: utc) == 1)
    #expect(countdown.remainingDays(at: date, timeZone: india) == 0)
    #expect(countdown.remainingDays(at: date, timeZone: la) == 1)
    let beforeDST = try #require(NOAAWeatherClient.date("2026-10-31T19:00:00Z"))
    #expect(countdown.remainingDays(at: beforeDST, timeZone: la) == 19)
    #expect(countdown.sample(at: date, timeZone: india).text["countdown.label"] == "Release day")
    let after = date.addingTimeInterval(3 * 86400)
    #expect(countdown.sample(at: after).numbers["countdown.days"] == 0)
    #expect(countdown.sample(at: after).text["countdown.label"] == "Scheduled release date reached")
    var invalid = countdown; invalid.month = 2; invalid.day = 30
    #expect(!invalid.isValid)
}

@Test func noaaDecodesCoordinatesAndRejectsMalformedGridsAndKp() throws {
    let date = Date(timeIntervalSince1970: 1_789_211_000)
    let data = try forecastFixture(at: date)
    let forecast = try NOAAWeatherClient.decodeForecast(data)
    #expect(forecast.grid.isValid && forecast.grid.width == 360 && forecast.grid.height == 181)
    #expect(forecast.grid.values[158 * 360] > 0.7) // 0° longitude, +68° latitude
    #expect(forecast.grid.values[90 * 360] < 0.001) // equator
    #expect(try forecast.grid.revision == NOAAWeatherClient.decodeForecast(data).grid.revision)
    #expect(throws: WallpaperError.invalidData) { try NOAAWeatherClient.decodeForecast(forecastFixture(at: date, badCoordinate: true)) }
    #expect(throws: (any Error).self) { try NOAAWeatherClient.decodeForecast(Data("{}".utf8)) }
    let kp = try NOAAWeatherClient.decodeKp(Data("[[\"time_tag\",\"Kp\"],[\"2026-09-12 09:00:00.000\",\"4.33\"],[\"bad\",\"-1\"]]".utf8))
    #expect(kp.value == 4.33)
    let object = try NOAAWeatherClient.decodeKp(Data("[{\"time_tag\":\"2026-09-12T09:00:00\",\"Kp\":3.0}]".utf8))
    #expect(object.value == 3)
    #expect(throws: WallpaperError.invalidData) { try NOAAWeatherClient.decodeKp(Data("[]".utf8)) }
    let invalid = WallpaperScalarGrid(revision: "x", width: 2, height: 2, values: [0, 0, 0, .nan])
    #expect(!invalid.isValid)
    #expect(throws: WallpaperError.invalidData) { try WallpaperDataSample(timestamp: date, grids: ["other.grid": forecast.grid]).validated(namespace: "aurora") }
}

private actor NOAAFixtureServer {
    let forecast: Data
    var calls = 0
    var offline = false
    init(_ forecast: Data) { self.forecast = forecast }
    func fail(_ value: Bool) { offline = value }
    func load(_ feed: NOAAWeatherClient.Feed) async throws -> Data {
        calls += 1
        try await Task.sleep(for: .milliseconds(10))
        if offline { throw URLError(.notConnectedToInternet) }
        return feed == .aurora ? forecast : Data("[{\"time_tag\":\"2026-09-12T09:00:00\",\"Kp\":5.0}]".utf8)
    }
}

@Test func noaaSharedCacheRetainsDataMarksStalenessAndRecovers() async throws {
    let date = try #require(NOAAWeatherClient.date("2026-09-12T10:00:00Z"))
    let server = NOAAFixtureServer(try forecastFixture(at: date))
    let store = NOAAWeatherStore(client: .init(load: { try await server.load($0) }))
    async let a = store.read(at: date)
    async let b = store.read(at: date)
    let (first, second) = try await (a, b)
    #expect(first.forecast?.grid.revision == second.forecast?.grid.revision)
    #expect(await server.calls == 2)
    _ = try await store.read(at: date.addingTimeInterval(299)); #expect(await server.calls == 2)
    await server.fail(true)
    let cached = try await store.read(at: date.addingTimeInterval(301))
    #expect(cached.forecastFailed && cached.forecast != nil)
    let sample = AuroraWallpaperProvider.snapshot(cached, at: date.addingTimeInterval(301))
    #expect(sample.status.hasPrefix("Cached forecast") && sample.grids?["aurora.oval"] != nil)
    #expect(AuroraWallpaperProvider.snapshot(cached, at: date.addingTimeInterval(8000)).status.hasPrefix("Stale forecast"))
    let stale = AuroraWallpaperProvider.snapshot(cached, at: date.addingTimeInterval(23000))
    #expect(stale.text["aurora.kpLabel"]?.contains("stale") == true)
    #expect(AuroraWallpaperProvider.snapshot(.init(), at: date).numbers.isEmpty)
    await server.fail(false)
    #expect(try await !store.read(at: date.addingTimeInterval(602)).forecastFailed)
    let task = Task { try await store.read(at: date.addingTimeInterval(1000)) }
    task.cancel()
    do { _ = try await task.value; Issue.record("Cancelled reader returned data") } catch is CancellationError {} catch { Issue.record(error) }
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func scalarGridUploadsOnlyNewRevisionsAndMissingDataClearsBinding() throws {
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context(), texture = try WallpaperGridTexture(device: gpu.device)
    let grid = WallpaperScalarGrid(revision: "one", width: 2, height: 2, values: [0, 0.5, 1, 0])
    let first = texture.texture(for: grid)
    #expect(texture.texture(for: grid) === first && texture.uploadCount == 1)
    #expect(texture.texture(for: nil).width == 1)
    let replacement = WallpaperScalarGrid(revision: "two", width: 2, height: 2, values: [1, 1, 1, 1])
    #expect(texture.texture(for: replacement) !== first && texture.uploadCount == 2)
}

@Test(.requiresGPU, .tags(.gpu)) @MainActor func newPublicWallpapersRenderForecastAndExportCompositions() throws {
    UnfoldMyMacType.register()
    let catalog = WallpaperShaderCatalog(), gpu = try TestGPU.context()
    let templates = try WallpaperTemplateRegistry(shaders: catalog, loadUserTemplates: false).templates
    let rawURL = ProcessInfo.processInfo.environment["UNFOLDMYMAC_AURORA_JSON"].map { URL(fileURLWithPath: $0) }
    let forecast = try NOAAWeatherClient.decodeForecast(rawURL.map { try Data(contentsOf: $0) } ?? forecastFixture(at: .now))
    var snapshot = WallpaperSnapshot()
    snapshot.sources["aurora"] = AuroraWallpaperProvider.snapshot(.init(forecast: forecast, kp: .init(date: .now, value: 3)), at: .now)
    for template in templates where ["aurora-observatory", "gta-vi-countdown"].contains(template.id) {
        let pipeline = try WallpaperPipeline(template: template, gpu: gpu, shaders: catalog)
        let harness = WallpaperHarness(pipeline: pipeline)
        let grid = template.gridBinding == nil ? nil : forecast.grid
        let rendered = try harness.render(time: 4, energy: 0.4, grid: grid)
        if grid != nil { #expect(try rendered.pixels != harness.render(time: 4, energy: 0.4).pixels) }
        guard let path = ProcessInfo.processInfo.environment["UNFOLDMYMAC_WALLPAPER_ARTIFACTS"] else { continue }
        let directory = URL(fileURLWithPath: path); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (width, height) in [(1280,800), (1720,720), (400,640)] {
            let pixels = try harness.render(time: 4, energy: 0.4, width: width, height: height, grid: grid).pixels
            #expect(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 })
            let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
            let cg = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width*4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent))
            if width == 1280 {
                try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(template.id+"-cover.png"))
            }
            let view = ZStack {
                Image(nsImage: NSImage(cgImage: cg, size: .init(width: width,height: height))).resizable()
                WallpaperLayers(template: template, snapshot: snapshot, animated: false)
            }.frame(width: CGFloat(width), height: CGFloat(height))
            let image = try #require(ImageRenderer(content: view).cgImage)
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(template.id)-\(width)x\(height).png"))
        }
    }
}
