import Foundation

/// Editorial copy supports inline Markdown; sections retain their own heading hierarchy.
public struct ContentSection: Codable, Equatable, Sendable {
    public var title: String
    public var body: String
    public init(title: String, body: String) { self.title = title; self.body = body }
}
