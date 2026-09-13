import Foundation
import UnfoldMyMacCore

/// Where the app is installed and whether it may replace itself there.
///
/// Separated from the updater so tests can place the app on a read-only volume, in a build tree, or
/// under App Translocation without any of those being true of the machine running the tests.
protocol UpdateEnvironmentProbing: Sendable {
    var bundleURL: URL { get }
    func eligibility() async -> UpdateEligibility
    func facts(currentVersion: AppVersion) async -> UpdateFacts
}
