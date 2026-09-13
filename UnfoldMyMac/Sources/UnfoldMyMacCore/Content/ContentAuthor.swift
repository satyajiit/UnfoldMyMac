import Foundation

/// A creator credit, independent of the products or data sources a design uses.
public struct ContentAuthor: Codable, Equatable, Sendable {
    public var name: String
    public var role: String?
    public var url: URL?
    public var logo: String?

    public init(name: String, role: String? = nil, url: URL? = nil, logo: String? = nil) {
        self.name = name; self.role = role; self.url = url; self.logo = logo
    }
    public var publicURL: URL? {
        guard let url, url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
    public var isValid: Bool {
        !name.isEmpty && name.count <= 120 && (role?.count ?? 0) <= 160 &&
        (url == nil || publicURL != nil) &&
        (logo == nil || logo?.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
    }
    public static let unfoldMyMac = ContentAuthor(name: AppIdentity.name, role: "Design & development",
        url: URL(string: AppIdentity.website), logo: "UnfoldMyMacMark")
    public static func legacy(_ name: String) -> ContentAuthor {
        name == AppIdentity.name ? .unfoldMyMac : .init(name: name)
    }
}
