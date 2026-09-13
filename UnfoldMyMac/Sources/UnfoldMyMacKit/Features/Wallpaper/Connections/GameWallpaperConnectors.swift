import Foundation

extension WallpaperConnectorRegistry {
    static let gameConnectors: [WallpaperConnectorDescriptor] = [
        .init(id: "battery-recovery", title: "Battery recovery", namespaces: ["power"], implicit: true,
              makeProvider: { _ in PowerWallpaperProvider() }),
        .init(id: "network-traffic", title: "Network traffic", namespaces: ["network"], implicit: true,
              makeProvider: { _ in NetworkWallpaperProvider() }),
        .init(id: "thermal-pressure", title: "Thermal pressure", namespaces: ["thermal"], implicit: true,
              makeProvider: { _ in ThermalWallpaperProvider() }),
        .init(id: "storage-inventory", title: "Storage inventory", namespaces: ["storage"], implicit: true,
              makeProvider: { _ in StorageWallpaperProvider() }),
        .init(id: "grace-focus", title: "Focus at Grace", namespaces: ["focus"], form: .restTimer,
              description: "Focus for 25 minutes, then rest for five. Focus pauses after one minute without input. Sleep never advances the timer. Starts when this scene is selected; changing duration starts a new session.",
              validate: { _ in true },
              makeProvider: { RestWallpaperProvider(mode: .focus, minutes: $0.restMinutes(default: 25), restart: $0.sessionRestart) }),
        .init(id: "greenpath-rest", title: "Quiet moments", namespaces: ["eyes"], form: .restTimer,
              description: "A gentle reminder after 20 minutes of screen time. Leave the mouse and keyboard alone for 20 seconds to reset it. Sleep never adds screen time. Changing duration starts a new reminder.",
              validate: { _ in true },
              makeProvider: { RestWallpaperProvider(mode: .eyes, minutes: $0.restMinutes(default: 20), restart: $0.sessionRestart) }),
        .init(id: "local-weather", title: "Your sky", namespaces: ["weather"], form: .weather,
              validate: { $0.enabled && $0.weatherLocation?.isValid == true },
              makeProvider: { settings in settings.weatherLocation.map { WeatherWallpaperProvider(location: $0) } }),
        .init(id: "wukong-steam", title: "Wukong on Steam", namespaces: ["wukong"], implicit: true,
              makeProvider: { _ in SteamWallpaperProvider() })
    ]
}
