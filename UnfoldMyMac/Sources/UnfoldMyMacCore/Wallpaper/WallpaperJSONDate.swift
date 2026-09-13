import Foundation

enum WallpaperJSONDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value)) ??
               (try? Date.ISO8601FormatStyle().parse(value))
    }
}
