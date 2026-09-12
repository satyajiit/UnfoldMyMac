import Foundation

/// A calendar date, deliberately not a claim about a worldwide unlock instant.
public struct WallpaperCountdown: Codable, Equatable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var sourceURL: URL
    public init(year: Int, month: Int, day: Int, sourceURL: URL) {
        self.year = year; self.month = month; self.day = day; self.sourceURL = sourceURL
    }
    public var isValid: Bool {
        guard (2000...2100).contains(year), (1...12).contains(month), (1...31).contains(day),
              sourceURL.scheme == "https", sourceURL.host != nil,
              let date = Calendar(identifier: .gregorian).date(from: .init(year: year, month: month, day: day)) else { return false }
        return Calendar(identifier: .gregorian).component(.day, from: date) == day
    }
    public func remainingDays(at date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        guard let target = calendar.date(from: .init(year: year, month: month, day: day)) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: target).day ?? 0
    }
    public func sample(at date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> WallpaperDataSample {
        let days = remainingDays(at: date, timeZone: timeZone)
        let label = days > 0 ? "Days until release" : days == 0 ? "Release day" : "Scheduled release date reached"
        return .init(timestamp: date, numbers: ["countdown.days": Double(max(0, days)), "countdown.energy": 0.4],
            text: ["countdown.value": days > 0 ? String(days) : "VI", "countdown.label": label],
            status: "Calendar days in your time zone · announced release date, not an unlock time")
    }
}
