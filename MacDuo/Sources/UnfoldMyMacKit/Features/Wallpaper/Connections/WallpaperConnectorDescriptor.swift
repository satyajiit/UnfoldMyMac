import Foundation
import UnfoldMyMacCore

/// How a connector is configured in the setup sheet.
enum WallpaperConnectorForm: Sendable { case toggle, file, url, githubProfile, codexHooks, claudeCode }

/// One kind of data connection a template can ask for: what it is called, which namespaces it feeds, how it is
/// configured, when a configuration counts as ready and how to build its provider. Adding a connector is one
/// descriptor; only a bespoke form needs a view.
struct WallpaperConnectorDescriptor: Identifiable, Sendable {
    let id: String
    let title: String
    let namespaces: Set<String>
    /// Needs no configuration: attached whenever a template binds one of its namespaces.
    let implicit: Bool
    let form: WallpaperConnectorForm
    let description: String
    let toggleTitle: String
    let validate: @Sendable (WallpaperConnectionSettings) -> Bool
    let makeProvider: @Sendable (WallpaperConnectionSettings) -> (any WallpaperDataProvider)?

    init(id: String, title: String, namespaces: Set<String>, implicit: Bool = false, form: WallpaperConnectorForm = .toggle,
         description: String = "", toggleTitle: String = "",
         validate: @escaping @Sendable (WallpaperConnectionSettings) -> Bool = { $0.enabled },
         makeProvider: @escaping @Sendable (WallpaperConnectionSettings) -> (any WallpaperDataProvider)?) {
        self.id = id; self.title = title; self.namespaces = namespaces; self.implicit = implicit; self.form = form
        self.description = description; self.toggleTitle = toggleTitle; self.validate = validate; self.makeProvider = makeProvider
    }
}
