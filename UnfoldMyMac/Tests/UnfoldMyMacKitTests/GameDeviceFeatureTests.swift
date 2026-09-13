import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

@Test func gameDeviceReadingsHandleResetsUnknownEstimatesAndPressure() throws {
    let date = Date.now
    let recovering = PowerWallpaperProvider.snapshot(level: 0.15, charging: true, plugged: true, minutes: 42, lowPower: false, at: date)
    #expect(recovering.numbers["power.low"] == 1 && recovering.numbers["power.charging"] == 1)
    #expect(recovering.text["power.detail"] == "About 42 min to full")
    let unknown = PowerWallpaperProvider.snapshot(level: 0.5, charging: false, plugged: false, minutes: -1, lowPower: false, at: date)
    #expect(unknown.text["power.detail"]?.contains("unavailable") == true)
    #expect(ThermalWallpaperProvider.snapshot(.critical, at: date).numbers["thermal.pressure"] == 1)
    #expect(ThermalWallpaperProvider.snapshot(.nominal, at: date).numbers["thermal.pressure"] == 0)
    let full = StorageWallpaperProvider.snapshot(free: 5, total: 100, at: date)
    #expect(full.text["storage.state"] == "INVENTORY ALMOST FULL")
    #expect(StorageWallpaperProvider.snapshot(free: 0, total: 0, at: date).numbers.isEmpty)
    let previous = ["en0": NetworkByteCount(received: 1_000, sent: 2_000)]
    let current = ["en0": NetworkByteCount(received: 3_000, sent: 3_000), "en1": NetworkByteCount(received: 9_000, sent: 9_000)]
    #expect(NetworkWallpaperProvider.rates(current: current, previous: previous, elapsed: 2) == .init(received: 1_000, sent: 500))
    #expect(NetworkWallpaperProvider.rates(current: previous, previous: current, elapsed: 1) == .init(received: 0, sent: 0))
    #expect(NetworkWallpaperProvider.rates(current: current, previous: previous, elapsed: 300) == .init(received: 0, sent: 0))
    #expect(try full.validated(namespace: "storage") == full)
}

@Test @MainActor func allGameFeaturesBindRealProvidersAndWeatherRequiresAChosenCity() throws {
    let registry = try WallpaperTemplateRegistry(shaders: WallpaperShaderCatalog(), loadUserTemplates: false)
    #expect(registry.errors.isEmpty)
    #expect(registry.warnings.isEmpty, "\(registry.warnings)")
    let location = WallpaperWeatherLocation(id: 1, name: "Pune", latitude: 18.52, longitude: 73.85)
    var metrics: Set<String> = []
    for id in gameWallpaperIDs {
        let template = try #require(registry.templates.first { $0.id == id })
        #expect(template.layers.contains { $0.id == "value" && $0.binding != nil })
        #expect(!(template.channels ?? []).isEmpty)
        metrics.insert(template.reactiveMetric)
        let connections: [String: WallpaperConnectionSettings] = ["local-weather": .init(enabled: true, weatherLocation: location)]
        let providers = WallpaperProviderAssembly.providers(for: template, connections: connections)
        #expect(template.dataNamespaces.isSubset(of: Set(providers.map(\.id))))
        #expect(template.contentCapabilities.contains(.publicAPI) == !template.dataNamespaces.isDisjoint(with: ["weather", "wukong"]))
        if template.dataNamespaces.contains("weather") {
            #expect(!WallpaperSetupController.isReady(template, connections: [:]))
            #expect(WallpaperSetupController.isReady(template, connections: connections))
            #expect(!WallpaperProviderAssembly.providers(for: template, connections: [:]).contains { $0.id == "weather" })
        }
    }
    #expect(metrics.count == 10)
    let legacy = try JSONDecoder().decode(WallpaperConnectionSettings.self, from: Data("{\"enabled\":false}".utf8))
    #expect(legacy.weatherLocation == nil && legacy.restMinutes(default: 25) == 25)
    let first = RestWallpaperProvider(mode: .focus, minutes: 25)
    let restarted = RestWallpaperProvider(mode: .focus, minutes: 25, restart: "new")
    #expect(first.fingerprint != restarted.fingerprint)
}
