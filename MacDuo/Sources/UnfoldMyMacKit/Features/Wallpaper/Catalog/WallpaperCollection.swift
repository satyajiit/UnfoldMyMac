import Foundation
import UnfoldMyMacCore

/// `Resources/Wallpapers/Collection.json`: the gallery's sections in order. A template naming no known category
/// is listed last under "More scenes".
struct WallpaperCollection: Decodable, Sendable {
    struct Category: Decodable, Identifiable, Equatable, Sendable {
        let id: String
        let title: String
    }
    struct Section: Identifiable {
        let category: Category
        let templates: [WallpaperTemplate]
        var id: String { category.id }
    }
    let version: Int
    let categories: [Category]

    static let other = Category(id: "other", title: "More scenes")
    static let standard = WallpaperCollection(version: 1, categories: [])

    static func bundled() throws -> WallpaperCollection {
        guard let url = BundleResources.wallpaperCollection else { throw BundleResourcesError.missing("Resources/Wallpapers/Collection.json") }
        let collection = try JSONDecoder().decode(WallpaperCollection.self, from: Data(contentsOf: url))
        guard collection.version == 1, Set(collection.categories.map(\.id)).count == collection.categories.count,
              collection.categories.allSatisfy({ !$0.title.isEmpty && $0.id != other.id }) else { throw WallpaperError.invalidField("Collection.json") }
        return collection
    }
    func category(for template: WallpaperTemplate) -> Category { categories.first { $0.id == template.category } ?? Self.other }
    /// Non-empty sections in collection order, preserving the templates' own order inside each.
    func sections(_ templates: [WallpaperTemplate]) -> [Section] {
        (categories + [Self.other]).compactMap { category in
            let members = templates.filter { self.category(for: $0) == category }
            return members.isEmpty ? nil : Section(category: category, templates: members)
        }
    }
}

/// `Resources/Wallpapers/Style.json`: the typography every template starts from.
enum WallpaperStyleSheet {
    static let bundled: WallpaperStyle = {
        guard let url = BundleResources.wallpaperStyle, let data = try? Data(contentsOf: url),
              let style = try? JSONDecoder().decode(WallpaperStyle.self, from: data), style.isValid else { return .standard }
        return style.merged(over: .standard)
    }()
}
