import Foundation

extension WallpaperTemplate {
    public var contentCollection: ContentCollection {
        metadata?.collection.flatMap(ContentCollection.init(rawValue:)) ?? .wallpapers
    }
    public var contentAuthors: [ContentAuthor] {
        guard let authors = metadata?.authors, !authors.isEmpty else { return [.legacy(author)] }
        return authors
    }
    public var contentCapabilities: [ContentCapability] {
        var result = Set<ContentCapability>()
        let connectors = Set((setup ?? []).map(\.id))
        if scene?.liveInputs == true { result.insert(.lid) }
        if connectors.contains("garden") { result.insert(.motion) }
        if connectors.contains("microphone") { result.insert(.microphone) }
        if !dataNamespaces.isDisjoint(with: ["mac", "power", "network", "thermal", "storage", "focus", "eyes"]) { result.insert(.macMetrics) }
        if dataNamespaces.contains("apps") { result.insert(.openApps) }
        if !connectors.isDisjoint(with: ["claude-code", "codex-history", "tool-file", "desktop-folder"]) { result.insert(.localFiles) }
        if connectors.contains("codex-activity") { result.insert(.hooks) }
        if !dataNamespaces.isDisjoint(with: ["github", "aurora", "weather", "wukong"]) { result.formUnion([.publicAPI, .network]) }
        if connectors.contains("http") { result.insert(.network) }
        return ContentCapability.allCases.filter(result.contains)
    }
    public func matchesDiscovery(query: String, category: String? = nil, tag: String? = nil) -> Bool {
        guard category == nil || self.category == category, tag.map(tags.contains) ?? true else { return false }
        let fields = [title, subtitle, author, metadata?.overview ?? ""] + tags + contentAuthors.map(\.name)
            + (metadata?.relatedBrands ?? []) + contentCapabilities.map(\.title)
        return ContentSearch.matches(query, fields: fields)
    }
}
