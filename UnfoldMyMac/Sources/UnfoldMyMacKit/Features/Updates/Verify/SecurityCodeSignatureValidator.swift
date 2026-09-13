import Foundation
import Security
import UnfoldMyMacCore

/// Checks Developer ID and notarization in process, through the Security framework.
///
/// Deliberately not `spctl`: that reports the *machine's* Gatekeeper policy, so on a Mac with
/// Gatekeeper turned off it accepts anything — worthless exactly when it matters. Deliberately not
/// `stapler` either, which needs developer tools an end user does not have. The `notarized` keyword
/// is evaluated here against the stapled ticket, offline, and never looks for the ticket file, whose
/// location inside a bundle is undocumented.
struct SecurityCodeSignatureValidator: CodeSignatureValidating {
    /// Also require the candidate to satisfy *this* process's designated requirement. Off inside the
    /// detached installer, where the running code is the very bundle being checked.
    var pinsToRunningIdentity = true

    /// The Developer ID Application leaf OID. Without it the requirement also accepts an *Apple
    /// Development* build, because a development certificate carries the same team OU — which would
    /// let any debug build of this team replace the shipping app.
    private static let developerIDLeaf = "field.1.2.840.113635.100.6.1.13"
    private static let developerIDAuthority = "field.1.2.840.113635.100.6.2.6"

    static func requirement(for artifact: SignedArtifact) -> String {
        var clauses = ["anchor apple generic"]
        // A disk image's signing identifier is derived from its file name (`UnfoldMyMac-1`), never
        // the bundle id, so pinning the identifier here would reject every image.
        if case .application = artifact { clauses.append("identifier \"\(AppIdentity.bundleIdentifier)\"") }
        clauses.append("certificate 1[\(developerIDAuthority)]")
        clauses.append("certificate leaf[\(developerIDLeaf)]")
        clauses.append("certificate leaf[subject.OU] = \"\(AppIdentity.teamIdentifier)\"")
        clauses.append("notarized")
        return clauses.joined(separator: " and ")
    }

    private static func flags(for artifact: SignedArtifact) -> SecCSFlags {
        switch artifact {
        case .application:
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode
                | kSecCSStrictValidate | kSecCSRestrictSymlinks | kSecCSRestrictSidebandData)
        case .diskImage:
            SecCSFlags(rawValue: kSecCSStrictValidate)
        }
    }

    func validate(_ url: URL, as artifact: SignedArtifact) throws {
        let code = try staticCode(at: url)
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(Self.requirement(for: artifact) as CFString, [], &requirement) == errSecSuccess,
              let requirement else { throw UpdateError.signatureRejected }
        guard SecStaticCodeCheckValidity(code, Self.flags(for: artifact), requirement) == errSecSuccess else {
            throw UpdateError.signatureRejected
        }
        // The replacement must also satisfy the running app's own designated requirement, so only a
        // build signed the way this one is can take its place. Using the requirement rather than the
        // certificate bytes means a Developer ID renewal does not strand everyone on this version.
        if pinsToRunningIdentity, case .application = artifact, let mine = Self.ownDesignatedRequirement() {
            guard SecStaticCodeCheckValidity(code, Self.flags(for: artifact), mine) == errSecSuccess else {
                throw UpdateError.signatureRejected
            }
        }
    }

    func runningApplicationIsRelease() -> Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(Self.requirement(for: .application) as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        return SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess
    }

    func securedInfoPlist(at url: URL) throws -> [String: Any] {
        let code = try staticCode(at: url)
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSInternalInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any],
              let plist = dictionary[kSecCodeInfoPList as String] as? [String: Any] else {
            throw UpdateError.signatureRejected
        }
        return plist
    }

    private func staticCode(at url: URL) throws -> SecStaticCode {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateError.signatureRejected
        }
        return code
    }

    private static func ownDesignatedRequirement() -> SecRequirement? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var statically: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &statically) == errSecSuccess, let statically else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(statically, SecCSFlags(rawValue: kSecCSRequirementInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return nil }
        guard let requirement = dictionary[kSecCodeInfoDesignatedRequirement as String] else { return nil }
        return (requirement as! SecRequirement)
    }
}
