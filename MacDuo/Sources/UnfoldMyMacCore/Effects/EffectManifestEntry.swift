import Foundation

/// One effect as `Effects.json` (or the artwork adapter) declares it: copy, category, cover, the renderer key
/// that `EffectRendererFactories` resolves, its capabilities and its adjustable parameters.
public struct EffectManifestEntry: Decodable, Sendable, Identifiable {
    public struct Capabilities: Decodable, Equatable, Sendable {
        public var requiresCapture = false
        public var continuousMotion = false
        public init(requiresCapture: Bool = false, continuousMotion: Bool = false) {
            self.requiresCapture = requiresCapture; self.continuousMotion = continuousMotion
        }
        private enum CodingKeys: String, CodingKey { case requiresCapture, continuousMotion }
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            requiresCapture = try values.decodeIfPresent(Bool.self, forKey: .requiresCapture) ?? false
            continuousMotion = try values.decodeIfPresent(Bool.self, forKey: .continuousMotion) ?? false
        }
    }
    public let id: EffectID
    public let title: String
    public let subtitle: String
    public let detail: String
    public let symbol: String
    public let category: EffectCategory
    public let tags: [String]
    public let author: String
    public let credit: String
    /// Resource path of the cover image, without extension: `Covers/Frost` or `Artwork/Reverie`.
    public let cover: String
    /// The image an image-based renderer draws, if any.
    public let asset: String?
    public let renderer: String
    public let renderingLabel: String
    public let capabilities: Capabilities
    public let parameters: [EffectParameterSpec]

    public init(id: EffectID, title: String, subtitle: String, detail: String, symbol: String, category: EffectCategory,
                tags: [String], author: String = AppIdentity.name, credit: String = "", cover: String, asset: String? = nil,
                renderer: String, renderingLabel: String, capabilities: Capabilities = .init(), parameters: [EffectParameterSpec]) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.detail = detail; self.symbol = symbol
        self.category = category; self.tags = tags; self.author = author; self.credit = credit; self.cover = cover
        self.asset = asset; self.renderer = renderer; self.renderingLabel = renderingLabel
        self.capabilities = capabilities; self.parameters = parameters
    }
    public var isValid: Bool {
        !id.rawValue.isEmpty && id.rawValue.count <= 80 && !title.isEmpty && !renderer.isEmpty && !cover.isEmpty &&
        !symbol.isEmpty && !tags.isEmpty && parameters.allSatisfy(\.isValid) &&
        Set(parameters.map(\.key)).count == parameters.count
    }
    public func descriptor(coverURL: URL?, isImported: Bool = false) -> EffectDescriptor {
        .init(id: id, title: title, subtitle: subtitle, detail: detail, symbol: symbol, requiresCapture: capabilities.requiresCapture,
              renderingLabel: renderingLabel, category: category, tags: tags, author: author, credit: credit, coverURL: coverURL,
              isImported: isImported, hasContinuousMotion: capabilities.continuousMotion, parameters: parameters)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, detail, symbol, category, tags, author, credit, cover, asset, renderer, renderingLabel, capabilities, parameters
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(EffectID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        subtitle = try values.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        detail = try values.decodeIfPresent(String.self, forKey: .detail) ?? ""
        symbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "sparkles"
        category = try values.decodeIfPresent(EffectCategory.self, forKey: .category) ?? .glass
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        author = try values.decodeIfPresent(String.self, forKey: .author) ?? AppIdentity.name
        credit = try values.decodeIfPresent(String.self, forKey: .credit) ?? ""
        cover = try values.decode(String.self, forKey: .cover)
        asset = try values.decodeIfPresent(String.self, forKey: .asset)
        renderer = try values.decode(String.self, forKey: .renderer)
        capabilities = try values.decodeIfPresent(Capabilities.self, forKey: .capabilities) ?? .init()
        renderingLabel = try values.decodeIfPresent(String.self, forKey: .renderingLabel) ?? (capabilities.requiresCapture ? "Live capture" : "Native")
        parameters = try values.decodeIfPresent([EffectParameterSpec].self, forKey: .parameters) ?? [.strength(title: "Intensity")]
    }
}
