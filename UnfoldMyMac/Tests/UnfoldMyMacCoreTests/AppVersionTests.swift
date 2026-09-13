import Foundation
import Testing
@testable import UnfoldMyMacCore

@Test func versionsParseFromBundleStringsAndReleaseTags() throws {
    #expect(AppVersion("1.0.1") == AppVersion(major: 1, minor: 0, patch: 1))
    #expect(AppVersion("v1.0.1") == AppVersion("1.0.1"), "A release tag carries a v this type has to look past")
    #expect(AppVersion("V1.0.1") == AppVersion("1.0.1"))
    #expect(AppVersion("  1.0.1  ") == AppVersion("1.0.1"))
    #expect(AppVersion("1") == AppVersion(major: 1))
    #expect(AppVersion("1.2") == AppVersion(major: 1, minor: 2))
    #expect(AppVersion("1.0.1.3") == AppVersion(major: 1, minor: 0, patch: 1, build: 3))
    #expect(AppVersion("1.0.1+abc") == AppVersion("1.0.1"), "Build metadata carries no precedence")
    #expect(AppVersion("1.2.0-beta.1")?.prerelease == "beta.1")
}

@Test func malformedVersionsAreRefusedRatherThanGuessedAt() {
    for raw in ["", "v", "1..1", "1.0.1.2.3", "one.two", "1.0.-1", "1.0.1-", "1.0.1-beta..1",
                "123456789.0.0", "1.0.1-beta!", " ", "-1.0.0"] {
        #expect(AppVersion(raw) == nil, "\(raw) is not a version and must not be read as one")
    }
}

@Test func fullWidthDigitsAreNotDigits() {
    // Int() accepts some non-ASCII digits, which would make a lookalike tag compare as a real one.
    #expect(AppVersion("１.０.１") == nil)
    #expect(AppVersion("1.٢.3") == nil)
}

@Test func versionsOrderByComponentThenPrerelease() {
    #expect(AppVersion("1.0.0")! < AppVersion("1.0.1")!)
    #expect(AppVersion("1.0.9")! < AppVersion("1.0.10")!, "Components compare as numbers, never as text")
    #expect(AppVersion("1.0.1")! < AppVersion("1.1.0")!)
    #expect(AppVersion("1.9.9")! < AppVersion("2.0.0")!)
    #expect(AppVersion("1.0.1")! == AppVersion("1.0.1.0")!, "A missing fourth component is zero")
    #expect(AppVersion("1.0.1")! < AppVersion("1.0.1.1")!)
    #expect(AppVersion("1.0.1-beta")! < AppVersion("1.0.1")!, "A prerelease ranks below its own release")
    #expect(AppVersion("1.0.1-beta.2")! < AppVersion("1.0.1-beta.10")!, "Numeric identifiers compare numerically")
    #expect(AppVersion("1.0.1-alpha")! < AppVersion("1.0.1-beta")!)
    #expect(AppVersion("1.0.1-1")! < AppVersion("1.0.1-alpha")!, "Numeric ranks below alphanumeric")
    #expect(AppVersion("1.0.1-beta")! < AppVersion("1.0.1-beta.1")!, "Fewer identifiers rank first")
}

@Test func printedVersionsParseBackToThemselves() throws {
    for raw in ["1.0.1", "1.0.1.3", "2.0.0", "1.2.0-beta.1"] {
        let version = try #require(AppVersion(raw))
        #expect(version.description == raw)
        #expect(AppVersion(version.description) == version, "The printed form is what gets persisted")
    }
}
