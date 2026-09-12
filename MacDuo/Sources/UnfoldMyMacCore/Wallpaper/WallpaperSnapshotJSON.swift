import Foundation

public enum WallpaperSnapshotJSON {
    public static func decode(_ data: Data, namespace: String) throws -> WallpaperDataSample {
        guard data.count <= 65_536 else { throw WallpaperError.invalidData }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = WallpaperJSONDate.parse(value) else { throw WallpaperError.invalidData }
            return date
        }
        return try decoder.decode(WallpaperDataSample.self, from: data).validated(namespace: namespace)
    }
}

enum WallpaperJSONDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value)) ??
               (try? Date.ISO8601FormatStyle().parse(value))
    }
}
