import Foundation

public struct WallpaperJSONLines: Sendable {
    private var pending = Data()
    private var discarding = false
    public private(set) var uncommittedByteCount = 0
    public let maximumLineBytes: Int
    public init(maximumLineBytes: Int = 4 * 1024 * 1024) { self.maximumLineBytes = maximumLineBytes }
    public mutating func append(_ chunk: Data) -> [Data] {
        var result: [Data] = []
        for part in chunk.split(separator: 10, omittingEmptySubsequences: false).enumerated() {
            if part.offset > 0 {
                if !discarding && !pending.isEmpty { result.append(pending) }
                pending.removeAll(keepingCapacity: true); discarding = false
                uncommittedByteCount = 0
            }
            if pending.count + part.element.count > maximumLineBytes { pending.removeAll(keepingCapacity: true); discarding = true }
            if !discarding { pending.append(contentsOf: part.element) }
            uncommittedByteCount += part.element.count
        }
        return result
    }
}
