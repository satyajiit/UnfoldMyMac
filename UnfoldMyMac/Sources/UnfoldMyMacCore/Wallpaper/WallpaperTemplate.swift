import Foundation

/// A scene as its `template.json` declares it. Version 1 fields are unchanged; version 2 adds presentation,
/// motion and shader details, every one optional so a v1 document decodes to today's constants.
public struct WallpaperTemplate: Codable, Identifiable, Equatable, Sendable {
    public static let currentVersion = 2
    public var version: Int
    public var id: String
    public var title: String
    public var subtitle: String
    public var author: String
    public var tags: [String]
    /// The scene shader's id. A template-owned `scene` registers under this id, which defaults to the template's own.
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
    // Version 2
    public var category: String? = nil
    public var credit: String? = nil
    public var order: Int? = nil
    public var canvas: WallpaperCanvas? = nil
    public var style: WallpaperStyle? = nil
    public var reactiveSmoothing: Double? = nil
    public var cover: WallpaperPosePreset? = nil
    public var reduceMotionPose: WallpaperPosePreset? = nil
    public var fpsCeiling: Int? = nil
    /// Energy while the reactive metric has no data yet (W6); zero keeps the scene at rest.
    public var idleEnergy: Double? = nil
    public var params: [String: Double]? = nil
    public var scene: WallpaperSceneSource? = nil
    /// Additive catalog metadata; legacy templates and saved settings keep their existing IDs.
    public var metadata: ContentMetadata? = nil

    public static let smoothingRange = 0.5...20.0
    public static let maximumParameters = WallpaperSceneSource.maximumParameters

    public var canvasSize: WallpaperCanvas { canvas ?? .standard }
    public var coverPose: WallpaperPosePreset { cover ?? .cover }
    public var stillPose: WallpaperPosePreset { reduceMotionPose ?? .still }
    public var smoothingRate: Double { reactiveSmoothing ?? 4 }
    public func styled(over base: WallpaperStyle) -> WallpaperStyle { style?.merged(over: base) ?? base }

    public var dataNamespaces: Set<String> {
        let keys = [reactiveMetric] + (channels ?? []).map(\.metric) + layers.compactMap(\.binding)
        var namespaces = Set(keys.map { String($0.prefix(while: { $0 != "." })) })
        if layers.contains(where: { $0.phrases != nil }) { namespaces.insert("scene") }
        if countdown != nil { namespaces.insert("countdown") }
        if let gridBinding { namespaces.insert(String(gridBinding.prefix(while: { $0 != "." }))) }
        return namespaces
    }
}
