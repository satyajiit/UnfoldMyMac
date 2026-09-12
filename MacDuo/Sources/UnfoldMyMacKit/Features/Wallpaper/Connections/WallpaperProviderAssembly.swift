import UnfoldMyMacCore

/// Turns a template plus its connections into the providers that feed it.
enum WallpaperProviderAssembly {
    /// The countdown the template declares, every implicit connector whose namespace it binds, and each configured
    /// connector that is enabled and valid for it. Providers carry their own identity for the data hub.
    static func providers(for template: WallpaperTemplate, connections: [String: WallpaperConnectionSettings],
                          registry: WallpaperConnectorRegistry = .standard) -> [any WallpaperDataProvider] {
        var providers: [any WallpaperDataProvider] = []
        if let countdown = template.countdown { providers.append(CountdownWallpaperProvider(countdown: countdown)) }
        let needed = template.dataNamespaces
        for connector in registry.connectors where !connector.namespaces.isDisjoint(with: needed) {
            let settings = connections[connector.id] ?? .init()
            guard connector.implicit || connector.validate(settings), let provider = connector.makeProvider(settings) else { continue }
            providers.append(provider)
        }
        return providers
    }
}
