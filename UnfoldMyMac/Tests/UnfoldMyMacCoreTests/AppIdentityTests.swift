import Foundation
import Testing
@testable import UnfoldMyMacCore

/// The public links ship inside a signed binary, so a typo cannot be fixed without another
/// notarization round trip. Prove each one parses and points where its name claims.
@Test func publicLinksParseAndPointAtTheRealDestinations() throws {
    let links = [AppIdentity.website, AppIdentity.repository, AppIdentity.contributing, AppIdentity.newIssue]
    for link in links {
        let url = try #require(URL(string: link), "\(link) is not a URL")
        #expect(url.scheme == "https")
        #expect(url.query == nil)
        #expect(!link.hasSuffix("/"))
    }
    #expect(URL(string: AppIdentity.website)?.host() == "unfoldmymac.com")
    for link in [AppIdentity.repository, AppIdentity.contributing, AppIdentity.newIssue] {
        #expect(URL(string: link)?.host() == "github.com")
        #expect(link.hasPrefix("\(AppIdentity.repository)"))
    }
    #expect(AppIdentity.contributing.hasSuffix("/blob/main/CONTRIBUTING.md"))
    #expect(AppIdentity.newIssue.hasSuffix("/issues/new/choose"))
}
