/// Composition root of the living-wallpaper feature.
@MainActor enum WallpaperFeature {
    static func make(dependencies: AppDependencies) -> WallpaperModel {
        WallpaperModel(preferences: dependencies.preferences, environment: dependencies.environment, surfaces: dependencies.surfaces,
                       gpu: dependencies.gpu, systemBackdrop: WallpaperSystemBackdrop())
    }
}
