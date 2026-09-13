import Foundation
import UnfoldMyMacCore

/// Illustrative inputs for the website's native recordings. No devices, accounts or network requests.
enum GamePreviewSamples {
    static func add(to snapshot: inout WallpaperSnapshot, time: Double) {
        let date = Date.now
        let wave = (1 + sin(time * .pi / 2)) / 2
        snapshot.sources["power"] = .init(timestamp: date,
            numbers: ["power.battery": 0.72, "power.charging": 1, "power.low": 0],
            text: ["power.level": "72%", "power.state": "HEALING FACTOR ACTIVE", "power.detail": "About 38 min to full"])
        let download = 3.4 + 1.6 * wave
        snapshot.sources["network"] = .init(timestamp: date,
            numbers: ["network.down": download, "network.up": 0.8 + wave * 0.4],
            text: ["network.download": String(format: "%.1f MB/s", download), "network.state": "↓ INBOUND · LIVE TRAFFIC",
                   "network.upload": String(format: "↑ %.1f MB/s", 0.8 + wave * 0.4), "network.scope": "MAC NETWORK · SAMPLE DATA"])
        snapshot.sources["thermal"] = .init(timestamp: date,
            numbers: ["thermal.pressure": 1.0 / 3],
            text: ["thermal.state": "WARM", "thermal.advice": "Your Mac is managing a little extra heat."])
        let focusRemaining = 1084 - Int(time)
        snapshot.sources["focus"] = .init(timestamp: date,
            numbers: ["focus.progress": 1 - Double(focusRemaining) / 1500, "focus.resting": 0],
            text: ["focus.timer": String(format: "%02d:%02d", focusRemaining / 60, focusRemaining % 60),
                   "focus.state": "FOCUS AT GRACE", "focus.detail": "25 minutes of focus, then a five-minute rest."])
        let eyesRemaining = 778 - Int(time)
        snapshot.sources["eyes"] = .init(timestamp: date,
            numbers: ["eyes.progress": 1 - Double(eyesRemaining) / 1200, "eyes.resting": 0],
            text: ["eyes.timer": String(format: "%02d:%02d", eyesRemaining / 60, eyesRemaining % 60),
                   "eyes.state": "A QUIET MOMENT SOON", "eyes.detail": "Look away for 20 seconds to reset the reminder."])
        snapshot.sources["weather"] = .init(timestamp: date,
            numbers: ["weather.rain": 1.6, "weather.day": 1, "weather.wind": 18, "weather.available": 1,
                      "weather.direction": 45, "weather.windValid": 1, "weather.sun": 0.96],
            text: ["weather.temperature": "21°C", "weather.condition": "LIGHT RAIN", "weather.rainfall": "Rain 1.6 mm · Wind 18 km/h",
                   "weather.source": "Open-Meteo · Sample data", "weather.location": "Kyoto",
                   "weather.clock": "17:42", "weather.sunNext": "Sunset in 21 min", "weather.sunTimes": "Sunrise 05:39 · Sunset 18:03",
                   "weather.windLabel": "18 km/h · NE", "weather.gusts": "Gusts up to 26 km/h"])
        snapshot.sources["storage"] = .init(timestamp: date,
            numbers: ["storage.used": 0.817, "storage.free": 0.183],
            text: ["storage.capacity": "183 GB", "storage.state": "ROOM FOR MORE ADVENTURES", "storage.detail": "817 GB used of 1 TB · Home volume"])
        snapshot.sources["wukong"] = .init(timestamp: date,
            numbers: ["wukong.players": 27153, "wukong.crowd": 0.74],
            text: ["wukong.scope": "STEAM PLAYERS WORLDWIDE", "wukong.news": "Publisher announcements appear here.",
                   "wukong.newsDate": "Example announcement", "wukong.source": "Steam · Sample data"])
    }
}
