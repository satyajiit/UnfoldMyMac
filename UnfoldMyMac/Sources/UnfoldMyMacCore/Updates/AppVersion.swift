import Foundation

/// A released version, parsed from `CFBundleShortVersionString` or from a `v`-prefixed release tag.
///
/// `CFBundleVersion` is deliberately not part of this type. The shipped value is a bare counter that
/// does not track the short string, so ordering releases by it would put them in the wrong sequence.
public struct AppVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    /// The optional fourth component. Zero when the version has three or fewer.
    public let build: Int
    /// The `beta.1` in `1.2.0-beta.1`, empty for a final release.
    public let prerelease: String

    public var isPrerelease: Bool { !prerelease.isEmpty }

    public init(major: Int, minor: Int = 0, patch: Int = 0, build: Int = 0, prerelease: String = "") {
        self.major = major; self.minor = minor; self.patch = patch; self.build = build; self.prerelease = prerelease
    }

    /// Accepts `1`, `1.2`, `1.2.3`, `1.2.3.4`, a leading `v`, and a `-prerelease` suffix.
    /// Build metadata after `+` carries no precedence and is discarded before parsing.
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        if let plus = text.firstIndex(of: "+") { text = String(text[..<plus]) }

        var suffix = ""
        if let dash = text.firstIndex(of: "-") {
            suffix = String(text[text.index(after: dash)...])
            text = String(text[..<dash])
            guard Self.isValidPrerelease(suffix) else { return nil }
        }
        let fields = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(fields.count) else { return nil }
        var numbers = [0, 0, 0, 0]
        for (index, field) in fields.enumerated() {
            // Explicit ASCII, never Character.isNumber: that accepts full-width and other Unicode digits.
            guard (1...8).contains(field.count), field.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let value = Int(field) else { return nil }
            numbers[index] = value
        }
        major = numbers[0]; minor = numbers[1]; patch = numbers[2]; build = numbers[3]
        prerelease = suffix
    }

    public var description: String {
        var text = "\(major).\(minor).\(patch)"
        if build != 0 { text += ".\(build)" }
        if !prerelease.isEmpty { text += "-\(prerelease)" }
        return text
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let left = [lhs.major, lhs.minor, lhs.patch, lhs.build]
        let right = [rhs.major, rhs.minor, rhs.patch, rhs.build]
        for (a, b) in zip(left, right) where a != b { return a < b }
        return comparePrerelease(lhs.prerelease, rhs.prerelease)
    }

    /// Semver §11: a version with a prerelease ranks below the same version without one.
    private static func comparePrerelease(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return false }
        if lhs.isEmpty { return false }
        if rhs.isEmpty { return true }
        let left = lhs.split(separator: ".", omittingEmptySubsequences: false)
        let right = rhs.split(separator: ".", omittingEmptySubsequences: false)
        for (a, b) in zip(left, right) {
            if a == b { continue }
            let x = numericValue(a), y = numericValue(b)
            switch (x, y) {
            case let (.some(x), .some(y)): return x < y            // 2 before 10, never "10" before "2"
            case (.some, .none): return true                       // numeric ranks below alphanumeric
            case (.none, .some): return false
            case (.none, .none): return a.lexicographicallyPrecedes(b)
            }
        }
        return left.count < right.count
    }

    private static func numericValue(_ field: Substring) -> Int? {
        guard !field.isEmpty, field.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return Int(field)
    }

    private static func isValidPrerelease(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let fields = text.split(separator: ".", omittingEmptySubsequences: false)
        return fields.allSatisfy { field in
            !field.isEmpty && field.utf8.allSatisfy {
                ($0 >= 48 && $0 <= 57) || ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || $0 == 45
            }
        }
    }
}
