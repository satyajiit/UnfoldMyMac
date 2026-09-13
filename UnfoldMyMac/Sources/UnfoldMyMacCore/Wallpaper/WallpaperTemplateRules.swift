import Foundation

/// Every rejection a template can earn, named by the field that failed so an author can fix it.
extension WallpaperTemplate {
    private static let assetPattern = #"^[A-Za-z0-9_-]+$"#
    private static let parameterPattern = #"^[A-Za-z_][A-Za-z0-9_]{0,31}$"#

    public func validated() throws -> Self {
        func require(_ condition: @autoclosure () -> Bool, _ field: String) throws {
            guard condition() else { throw WallpaperError.invalidField(field) }
        }
        try require((1...Self.currentVersion).contains(version), "version")
        try require(!id.isEmpty && id.count <= 80 && !id.contains("/") && !id.contains("..") && id.trimmingCharacters(in: .whitespaces) == id, "id")
        try require(!title.isEmpty && title.count <= 80, "title")
        try require(subtitle.count <= 240, "subtitle")
        try require(author.count <= 80, "author")
        try require(tags.count <= 12 && tags.allSatisfy { !$0.isEmpty && $0.count <= 40 }, "tags")
        try require(!shader.isEmpty && shader.count <= 80, "shader")
        try require(accent <= 0xFFFFFF, "accent")
        try require(background <= 0xFFFFFF, "background")
        try require(reactiveMetric.count <= 100 && reactiveMetric.contains(".") && !reactiveMetric.hasPrefix(".") && !reactiveMetric.hasSuffix("."), "reactiveMetric")
        try require(reactiveScale.isFinite && reactiveScale > 0, "reactiveScale")
        try require((channels?.count ?? 0) <= 4, "channels")
        for (index, channel) in (channels ?? []).enumerated() { try require(channel.isValid, "channels[\(index)]") }
        try require(emblem?.isValid ?? true, "emblem")
        try require(countdown?.isValid ?? true, "countdown")
        try require(informationURL == nil || (informationURL!.scheme == "https" && informationURL!.host != nil), "informationURL")
        try require(coverImage == nil || coverImage!.range(of: Self.assetPattern, options: .regularExpression) != nil, "coverImage")
        try require(image == nil || image!.range(of: Self.assetPattern, options: .regularExpression) != nil, "image")
        try require(gridBinding == nil || (gridBinding!.count <= 100 && gridBinding!.contains(".")), "gridBinding")
        try require((setup?.count ?? 0) <= 5 && Set((setup ?? []).map(\.kind)).count == (setup?.count ?? 0), "setup")
        for (index, requirement) in (setup ?? []).enumerated() { try require(requirement.kind.isValid, "setup[\(index)].kind") }
        try require((0...32).contains(layers.count) && Set(layers.map(\.id)).count == layers.count, "layers")
        for (index, layer) in layers.enumerated() { try require(layer.isValid, "layers[\(index)]") }
        try validatedPresentation()
        return self
    }
    private func validatedPresentation() throws {
        func require(_ condition: @autoclosure () -> Bool, _ field: String) throws {
            guard condition() else { throw WallpaperError.invalidField(field) }
        }
        try require(category == nil || category!.range(of: #"^[a-z0-9][a-z0-9-]{0,39}$"#, options: .regularExpression) != nil, "category")
        try require(credit == nil || credit!.count <= 160, "credit")
        try require(order == nil || (0...10_000).contains(order!), "order")
        try require(canvas?.isValid ?? true, "canvas")
        try require(style?.isValid ?? true, "style")
        try require(reactiveSmoothing == nil || Self.smoothingRange.contains(reactiveSmoothing!), "reactiveSmoothing")
        try require(cover?.isValid ?? true, "cover")
        try require(reduceMotionPose?.isValid ?? true, "reduceMotionPose")
        try require(fpsCeiling == nil || (1...120).contains(fpsCeiling!), "fpsCeiling")
        try require(idleEnergy == nil || (idleEnergy!.isFinite && (0...1).contains(idleEnergy!)), "idleEnergy")
        try require((params?.count ?? 0) <= Self.maximumParameters, "params")
        for (key, value) in params ?? [:] {
            try require(key.range(of: Self.parameterPattern, options: .regularExpression) != nil && value.isFinite, "params.\(key)")
        }
        try require(scene?.isValid ?? true, "scene")
        try require(metadata?.isValid ?? true, "metadata")
    }
}
