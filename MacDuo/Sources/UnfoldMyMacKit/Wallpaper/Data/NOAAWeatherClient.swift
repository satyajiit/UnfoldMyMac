import Foundation
import CryptoKit
import UnfoldMyMacCore

struct NOAAForecast: Sendable {
    let observation: Date
    let forecast: Date
    let grid: WallpaperScalarGrid
}
struct NOAAKp: Sendable { let date: Date; let value: Double }

/// Network and decoding stay outside both the provider heartbeat and render loop.
struct NOAAWeatherClient: Sendable {
    enum Feed: String, Sendable {
        case aurora = "json/ovation_aurora_latest.json"
        case kp = "products/noaa-planetary-k-index.json"
    }
    var load: @Sendable (Feed) async throws -> Data = { feed in
        var request = URLRequest(url: URL(string: "https://services.swpc.noaa.gov/" + feed.rawValue)!)
        request.timeoutInterval = 15
        request.setValue("UnfoldMyMac/1.0", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= 2_000_000 else { throw WallpaperError.unavailable("NOAA is temporarily unavailable.") }
        var data = Data(); data.reserveCapacity(1_000_000)
        for try await byte in bytes {
            if data.count >= 2_000_000 { throw WallpaperError.invalidData }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }
    func forecast() async throws -> NOAAForecast { try Self.decodeForecast(await load(.aurora)) }
    func kp() async throws -> NOAAKp { try Self.decodeKp(await load(.kp)) }

    static func date(_ string: String) -> Date? {
        let normalized = string.replacingOccurrences(of: " ", with: "T")
        let value = normalized.hasSuffix("Z") ? normalized : normalized + "Z"
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
    static func decodeForecast(_ data: Data) throws -> NOAAForecast {
        guard data.count <= 2_000_000,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let observed = object["Observation Time"] as? String, let observation = date(observed),
              let predicted = object["Forecast Time"] as? String, let forecast = date(predicted),
              let coordinates = object["coordinates"] as? [[Double]], coordinates.count == 360 * 181 else { throw WallpaperError.invalidData }
        // NOAA longitude is 0...359; rows run from -90 (south) to +90 (north).
        var values = [Float](repeating: 0, count: 360 * 181)
        var seen = Set<Int>(); seen.reserveCapacity(values.count)
        for point in coordinates {
            guard point.count == 3, point.allSatisfy(\.isFinite),
                  (0..<360).contains(point[0]), (-90...90).contains(point[1]), (0...100).contains(point[2]),
                  point[0].rounded() == point[0], point[1].rounded() == point[1] else { throw WallpaperError.invalidData }
            let index = (Int(point[1]) + 90) * 360 + Int(point[0])
            guard seen.insert(index).inserted else { throw WallpaperError.invalidData }
            values[index] = Float(point[2] / 100)
        }
        let revision = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return .init(observation: observation, forecast: forecast,
            grid: .init(revision: revision, width: 360, height: 181, values: values))
    }
    static func decodeKp(_ data: Data) throws -> NOAAKp {
        guard data.count <= 2_000_000 else { throw WallpaperError.invalidData }
        let raw = try JSONSerialization.jsonObject(with: data)
        var readings: [NOAAKp] = []
        if let rows = raw as? [[String: Any]] {
            readings = rows.compactMap { row in
                guard let time = row["time_tag"] as? String, let date = date(time),
                      let value = row["Kp"] as? Double, value.isFinite, (0...9).contains(value) else { return nil }
                return .init(date: date, value: value)
            }
        } else if let rows = raw as? [[String]], let header = rows.first,
                  let ti = header.firstIndex(of: "time_tag"), let ki = header.firstIndex(of: "Kp") {
            readings = rows.dropFirst().compactMap { row in
                guard row.count > max(ti, ki), let date = date(row[ti]), let value = Double(row[ki]),
                      value.isFinite, (0...9).contains(value) else { return nil }
                return .init(date: date, value: value)
            }
        }
        guard let latest = readings.max(by: { $0.date < $1.date }) else { throw WallpaperError.invalidData }
        return latest
    }
}
