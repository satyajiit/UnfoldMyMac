import Foundation

public struct WallpaperTemplate: Codable, Identifiable, Equatable, Sendable {
    public var version: Int
    public var id: String
    public var title: String
    public var subtitle: String
    public var author: String
    public var tags: [String]
    public var shader: String
    public var accent: UInt32
    public var background: UInt32
    public var image: String?
    public var reactiveMetric: String
    public var reactiveScale: Double
    public var channels: [WallpaperChannel]?
    public var emblem: WallpaperEmblem? = nil
    public var layers: [WallpaperLayer]
    public var setup: [WallpaperSetupRequirement]? = nil
    public var countdown: WallpaperCountdown? = nil
    public var gridBinding: String? = nil
    public var coverImage: String? = nil
    public var informationURL: URL? = nil
    public var allowsCustomBackground: Bool? = nil
    public var dataNamespaces: Set<String> {
        let keys = [reactiveMetric] + (channels ?? []).map(\.metric) + layers.compactMap(\.binding)
        var namespaces = Set(keys.map { String($0.prefix(while: { $0 != "." })) })
        if layers.contains(where: { $0.phrases != nil }) { namespaces.insert("scene") }
        if countdown != nil { namespaces.insert("countdown") }
        if let gridBinding { namespaces.insert(String(gridBinding.prefix(while: { $0 != "." }))) }
        return namespaces
    }

    public func validated() throws -> Self {
        guard version == 1, !id.isEmpty, id.count <= 80,
              !title.isEmpty, title.count <= 80, subtitle.count <= 240,
              author.count <= 80, tags.count <= 12, !shader.isEmpty,
              reactiveScale.isFinite, reactiveScale > 0,
              (channels?.count ?? 0) <= 4, channels?.allSatisfy(\.isValid) ?? true,
              emblem?.isValid ?? true,
              countdown?.isValid ?? true,
              informationURL == nil || (informationURL!.scheme == "https" && informationURL!.host != nil),
              coverImage == nil || coverImage!.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
              gridBinding == nil || (gridBinding!.count <= 100 && gridBinding!.contains(".")),
              (setup?.count ?? 0) <= 5, Set((setup ?? []).map(\.kind)).count == (setup?.count ?? 0),
              (1...32).contains(layers.count), Set(layers.map(\.id)).count == layers.count,
              layers.allSatisfy(\.isValid),
              image == nil || (image!.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        else { throw WallpaperError.invalidTemplate }
        return self
    }
}

/// Four additional normalized signals are available to custom shaders as u.channels.
