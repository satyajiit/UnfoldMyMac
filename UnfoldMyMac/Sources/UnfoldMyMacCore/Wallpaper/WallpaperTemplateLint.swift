import Foundation

/// Checks that need the host's knowledge: which connectors, namespaces, categories and scene parameters exist.
/// A required connector this build lacks rejects the template; everything else is a warning.
enum WallpaperTemplateLint {
    static let minimumContrast = 3.0

    static func check(_ template: WallpaperTemplate, context: WallpaperTemplateSchema.Context) throws -> [WallpaperTemplateWarning] {
        var warnings: [WallpaperTemplateWarning] = []
        for (index, layer) in template.layers.enumerated() {
            let (ink, paper) = layer.kind == .sticker ? (template.background, layer.color) : (layer.color, template.background)
            let contrast = UnfoldMyMacColors.contrast(ink, paper)
            if contrast < minimumContrast {
                warnings.append(.init(.lowContrast, "Layer ‘\(layer.id)’ (layers[\(index)]) has a contrast ratio of \(String(format: "%.1f", contrast)) against its background; 3.0 keeps text readable."))
            }
        }
        if let categories = context.categories, let category = template.category, !categories.contains(category) {
            warnings.append(.init(.unknownCategory, "The category ‘\(category)’ is not in the collection; the template is listed under Other."))
        }
        if let connectors = context.connectors {
            for requirement in template.setup ?? [] where !connectors.contains(requirement.id) {
                if requirement.required { throw WallpaperError.unknownConnector(requirement.id) }
                warnings.append(.init(.unknownConnector, "The optional connector ‘\(requirement.id)’ is not available in this version."))
            }
        }
        if let namespaces = context.namespaces {
            for namespace in template.dataNamespaces.sorted() where !namespaces.contains(namespace) {
                warnings.append(.init(.unboundNamespace, "No connector feeds ‘\(namespace).*’; those layers show their placeholder text."))
            }
        }
        if let declared = template.scene?.parameterKeys ?? context.sceneParameters?[template.shader] {
            for key in (template.params ?? [:]).keys.sorted() where !declared.contains(key) {
                warnings.append(.init(.unknownParameter, "The scene ‘\(template.shader)’ declares no parameter ‘\(key)’; the value is ignored."))
            }
        }
        return warnings
    }
}
