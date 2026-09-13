import Foundation
import UnfoldMyMacCore

/// Composition root of the updater.
@MainActor enum UpdateFeature {
    static func make(dependencies: AppDependencies, version: String) -> UpdateModel {
        UpdateModel(preferences: dependencies.preferences,
                    currentVersion: AppVersion(version) ?? AppVersion(major: 0),
                    environment: dependencies.updateEnvironment)
    }
}

extension UpdateModel: UpdatePrompting {}
