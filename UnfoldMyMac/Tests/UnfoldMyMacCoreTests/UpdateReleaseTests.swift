import Foundation
import Testing
@testable import UnfoldMyMacCore

private let base = "https://github.com/satyajiit/UnfoldMyMac/releases/download/v1.0.2/"

private func asset(_ name: String, size: Int64 = 54, type: String = UpdateRelease.diskImageContentType,
                   host: String = base) -> ReleaseAsset {
    ReleaseAsset(name: name, downloadURL: URL(string: host + name)!, size: size, contentType: type)
}
private let sums = ReleaseAsset(name: "SHA256SUMS", downloadURL: URL(string: base + "SHA256SUMS")!,
                                size: 88, contentType: "application/octet-stream")

@Test func aWellFormedReleaseBecomesSomethingInstallable() throws {
    let release = try UpdateRelease.make(tag: "v1.0.2", notes: "notes", publishedAt: nil, isDraft: false,
                                         isPrerelease: false, assets: [asset("UnfoldMyMac-1.0.2.dmg"), sums])
    #expect(release.version == AppVersion("1.0.2"))
    #expect(release.assetName == "UnfoldMyMac-1.0.2.dmg")
    #expect(release.checksumURL != nil, "Without a checksum there is nothing to fail fast against")
}

@Test func draftsAndPrereleasesAreNeverOffered() {
    let good = [asset("UnfoldMyMac-1.0.2.dmg"), sums]
    #expect(throws: UpdateError.releaseHasNoDownload) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: true, isPrerelease: false, assets: good)
    }
    #expect(throws: UpdateError.releaseHasNoDownload) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: true, assets: good)
    }
    // Gated a second time on the tag itself, because a checkbox on a hand-cut release can be missed.
    #expect(throws: UpdateError.releaseHasNoDownload) {
        try UpdateRelease.make(tag: "v1.0.2-beta.1", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false,
                               assets: [asset("UnfoldMyMac-1.0.2-beta.1.dmg"), sums])
    }
}

@Test func aReleaseWhoseFilesDisagreeWithItsTagIsRefusedBeforeAnythingIsDownloaded() {
    #expect(throws: UpdateError.releaseVersionMismatch) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false,
                               assets: [asset("UnfoldMyMac-1.0.3.dmg"), sums])
    }
    #expect(throws: UpdateError.releaseVersionMismatch) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false,
                               assets: [asset("UnfoldMyMac-1.0.2.dmg", type: "application/zip"), sums])
    }
}

@Test func aReleaseMustPublishExactlyOneImageAndAChecksum() {
    #expect(throws: UpdateError.releaseHasNoDownload) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false, assets: [sums])
    }
    #expect(throws: UpdateError.releaseHasNoDownload) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false,
                               assets: [asset("UnfoldMyMac-1.0.2.dmg"), asset("Other-1.0.2.dmg"), sums])
    }
    #expect(throws: UpdateError.noChecksumPublished) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false,
                               assets: [asset("UnfoldMyMac-1.0.2.dmg")])
    }
}

@Test func onlyOurOwnOriginMayStartADownload() {
    #expect(throws: UpdateError.unexpectedRedirect) {
        try UpdateRelease.make(tag: "v1.0.2", notes: "", publishedAt: nil, isDraft: false, isPrerelease: false,
                               assets: [asset("UnfoldMyMac-1.0.2.dmg", host: "https://example.com/"), sums])
    }
    #expect(throws: UpdateError.unexpectedRedirect) {
        try UpdateRelease.validate(URL(string: "http://github.com/x.dmg")!)
    }
}

@Test func theChecksumFileIsReadStrictlyOrNotAtAll() {
    let digest = String(repeating: "a", count: 64)
    #expect(ChecksumManifest.digest(for: "UnfoldMyMac-1.0.2.dmg", in: "\(digest)  UnfoldMyMac-1.0.2.dmg\n") == digest)
    #expect(ChecksumManifest.digest(for: "UnfoldMyMac-1.0.2.dmg", in: "\(digest)  *UnfoldMyMac-1.0.2.dmg") == digest,
            "coreutils writes a binary marker some release tooling copies")
    // A manifest describing a different file must not validate the one we fetched.
    #expect(ChecksumManifest.digest(for: "UnfoldMyMac-1.0.2.dmg", in: "\(digest)  Something-Else.dmg") == nil)
    #expect(ChecksumManifest.digest(for: "UnfoldMyMac-1.0.2.dmg", in: "\(digest.dropLast())  UnfoldMyMac-1.0.2.dmg") == nil)
    #expect(ChecksumManifest.digest(for: "UnfoldMyMac-1.0.2.dmg", in: "\(digest.uppercased())  UnfoldMyMac-1.0.2.dmg") == nil)
    #expect(ChecksumManifest.digest(for: "UnfoldMyMac-1.0.2.dmg",
                                    in: "\(digest)  UnfoldMyMac-1.0.2.dmg\n\(digest)  UnfoldMyMac-1.0.2.dmg") == nil,
            "Two digests for one file means we cannot know which was meant")
    #expect(ChecksumManifest.digest(for: "x.dmg", in: String(repeating: "a", count: 5000)) == nil)
}
