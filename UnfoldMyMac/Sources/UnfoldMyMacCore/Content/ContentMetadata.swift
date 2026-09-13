import Foundation

/// Optional editorial schema shared by effects and scene templates. No rendering or account state.
public struct ContentMetadata: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var collection: String?
    public var overview: String?
    public var sections: [ContentSection]?
    public var authors: [ContentAuthor]?
    public var relatedBrands: [String]?
    public var banner: String?
    public var badge: String?

    public var isValid: Bool {
        version == 1 && (collection?.count ?? 0) <= 40 && (overview?.count ?? 0) <= 8_000 && (sections?.count ?? 0) <= 12 &&
        (sections ?? []).allSatisfy { !$0.title.isEmpty && $0.title.count <= 100 && $0.body.count <= 8_000 } &&
        (authors?.count ?? 0) <= 12 && (authors ?? []).allSatisfy(\.isValid) &&
        (relatedBrands?.count ?? 0) <= 8 && Set(relatedBrands ?? []).count == (relatedBrands?.count ?? 0) &&
        (relatedBrands ?? []).allSatisfy { !$0.isEmpty && $0.count <= 40 } &&
        (banner == nil || banner?.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil) && (badge?.count ?? 0) <= 24
    }

    public init(collection: String? = nil, overview: String? = nil, sections: [ContentSection]? = nil,
                authors: [ContentAuthor]? = nil, relatedBrands: [String]? = nil, banner: String? = nil, badge: String? = nil) {
        self.collection = collection; self.overview = overview; self.sections = sections; self.authors = authors
        self.relatedBrands = relatedBrands; self.banner = banner; self.badge = badge
    }
}
