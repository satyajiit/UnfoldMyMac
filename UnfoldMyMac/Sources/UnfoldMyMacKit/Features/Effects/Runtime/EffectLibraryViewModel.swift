import Observation
import UnfoldMyMacCore

/// Browse state of the design library: the category tab, search text, tag filter and the catalog message.
@MainActor @Observable final class EffectLibraryViewModel {
    var category: EffectCategory?
    var query = ""
    var tag: String?
    var message: String?

    init(message: String? = nil) { self.message = message }

    /// After an import the library shows the new image where the user will look for it.
    func showImported() { category = .image; tag = nil; query = "" }
    func filtered(_ descriptors: [EffectDescriptor]) -> [EffectDescriptor] {
        descriptors.filter { $0.matches(query: query, category: category, tag: tag) }
    }
    /// Tags offered by the tag picker: every tag in the current category, sorted.
    func availableTags(in descriptors: [EffectDescriptor]) -> [String] {
        Array(Set(descriptors.filter { category == nil || $0.category == category }.flatMap(\.tags))).sorted()
    }
}
