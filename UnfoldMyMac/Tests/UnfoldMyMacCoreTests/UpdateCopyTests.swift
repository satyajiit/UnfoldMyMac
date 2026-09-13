import Foundation
import Testing
@testable import UnfoldMyMacCore

/// The updater's messages ship inside a signed binary and are the only explanation a user gets when
/// an update will not happen. Hold every one of them to the same bar, the way `AppIdentityTests`
/// holds the public links.
@Test func everyUpdateFailureExplainsItselfInPlainLanguage() throws {
    for error in UpdateError.allCases {
        let message = try #require(error.errorDescription, "\(error) has no message")
        #expect(message.count > 30, "\(error) is too terse to help anyone")
        #expect(message.count < 340, "\(error) is longer than a sheet footer can show")
        #expect(message.hasSuffix(".") || message.hasSuffix("?"), "\(error) is not a complete sentence")
        #expect(message.first?.isUppercase == true, "\(error) does not start a sentence")
        // No path may reach a user: it would leak their home directory into the interface.
        #expect(!message.contains("/"), "\(error) leaks a file path")
        for jargon in ["nil", "URLError", "errSec", "Optional(", "Error Domain", "throw", "()"] {
            #expect(!message.contains(jargon), "\(error) shows developer wording: \(jargon)")
        }
    }
}

@Test func everyReasonUpdatingIsOffAlsoSaysHowToTurnItOn() throws {
    for block in UpdateBlock.allCases {
        let message = block.message
        #expect(message.count > 40, "\(block) does not explain itself")
        #expect(message.hasSuffix("."), "\(block) is not a complete sentence")
        #expect(!message.contains("/"), "\(block) leaks a file path")
    }
}

@Test func everyFailureIsFiledUnderThePhaseItsRetryBelongsTo() {
    #expect(UpdateError.offline.phase == .download)
    #expect(UpdateError.signatureRejected.phase == .verify)
    #expect(UpdateError.checksumMismatch.phase == .verify)
    #expect(UpdateError.diskImageStillMounted.phase == .stage)
    #expect(UpdateError.updateRolledBack.phase == .stage)
}
