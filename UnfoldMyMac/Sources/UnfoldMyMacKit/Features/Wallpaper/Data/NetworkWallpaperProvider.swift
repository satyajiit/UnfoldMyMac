import Foundation
import Darwin
import UnfoldMyMacCore

struct NetworkByteCount: Equatable, Sendable {
    var received: UInt64
    var sent: UInt64
}

/// Counts physical interfaces once, excluding loopback, VPN tunnels and peer-to-peer duplication.
actor NetworkWallpaperProvider: WallpaperDataProvider {
    nonisolated let id = "network"
    nonisolated let interval: TimeInterval = 1
    private var previous: [String: NetworkByteCount] = [:]
    private var previousTime: TimeInterval?

    func sample(at date: Date) async throws -> WallpaperDataSample {
        let counters = Self.readCounters()
        let uptime = ProcessInfo.processInfo.systemUptime
        let rates = Self.rates(current: counters, previous: previous, elapsed: previousTime.map { uptime - $0 } ?? 0)
        previous = counters; previousTime = uptime
        let down = rates.received, up = rates.sent
        return .init(timestamp: date, numbers: ["network.down": Double(down) / 1_000_000, "network.up": Double(up) / 1_000_000],
                     text: ["network.download": Self.rateLabel(down), "network.upload": "↑ " + Self.rateLabel(up),
                            "network.state": counters.isEmpty ? "NO ACTIVE INTERFACE" : "↓ INBOUND · LIVE TRAFFIC",
                            "network.scope": "Physical interfaces · traffic rate, not connection speed"])
    }

    static func rates(current: [String: NetworkByteCount], previous: [String: NetworkByteCount], elapsed: TimeInterval) -> NetworkByteCount {
        guard elapsed > 0, elapsed < 10 else { return .init(received: 0, sent: 0) }
        var down: Double = 0, up: Double = 0
        for (name, now) in current {
            guard let old = previous[name], now.received >= old.received, now.sent >= old.sent else { continue }
            down += Double(now.received - old.received) / elapsed
            up += Double(now.sent - old.sent) / elapsed
        }
        return .init(received: UInt64(min(down, 1e12)), sent: UInt64(min(up, 1e12)))
    }
    private static func rateLabel(_ bytes: UInt64) -> String {
        bytes >= 1_000_000 ? String(format: "%.1f MB/s", Double(bytes) / 1_000_000) : String(format: "%.0f KB/s", Double(bytes) / 1_000)
    }
    private static func readCounters() -> [String: NetworkByteCount] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return [:] }
        defer { freeifaddrs(list) }
        var result: [String: NetworkByteCount] = [:]
        var cursor = list
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let item = entry.pointee
            guard item.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), item.ifa_flags & UInt32(IFF_UP) != 0,
                  let name = item.ifa_name, let data = item.ifa_data else { continue }
            let interface = String(cString: name)
            guard interface.hasPrefix("en") else { continue }
            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            result[interface] = .init(received: UInt64(counters.ifi_ibytes), sent: UInt64(counters.ifi_obytes))
        }
        return result
    }
}
