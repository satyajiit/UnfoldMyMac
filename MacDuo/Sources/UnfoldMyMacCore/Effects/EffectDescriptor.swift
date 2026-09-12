import Foundation

public struct EffectDescriptor: Identifiable, Sendable {
    public let id: EffectID
    public let title: String
    public let subtitle: String
    public let detail: String
    public let symbol: String
    public let requiresCapture: Bool
    public let parameterTitle: String
    public let renderingLabel: String
    public let category: EffectCategory
    public let tags: [String]
    public let author: String
    public let credit: String
    public let coverURL: URL?
    public let hasContinuousMotion: Bool
    public let isImported: Bool
    public let defaultReveal: ArtRevealMotion?

    public func matches(query: String, category: EffectCategory? = nil, tag: String? = nil) -> Bool {
        guard category == nil || self.category == category,
              tag.map(tags.contains) ?? true else { return false }
        let haystack = ([title, subtitle, detail, author, credit, self.category.title] + tags).joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { haystack.localizedStandardContains(String($0)) }
    }

    public init(id: EffectID, title: String, subtitle: String, detail: String, symbol: String, requiresCapture: Bool = false,
                parameterTitle: String = "Intensity", renderingLabel: String? = nil,
                category: EffectCategory = .glass, tags: [String] = [], author: String = AppIdentity.name,
                credit: String = "", coverURL: URL? = nil, isImported: Bool = false, hasContinuousMotion: Bool = false, defaultReveal: ArtRevealMotion? = nil) {
        self.id = id; self.title = title; self.subtitle = subtitle
        self.detail = detail; self.symbol = symbol; self.requiresCapture = requiresCapture
        self.category = category; self.tags = tags; self.author = author; self.credit = credit
        self.hasContinuousMotion = hasContinuousMotion
        self.coverURL = coverURL; self.isImported = isImported; self.defaultReveal = defaultReveal
        self.parameterTitle = parameterTitle
        self.renderingLabel = renderingLabel ?? (requiresCapture ? "Live capture" : "Native")
    }
}
