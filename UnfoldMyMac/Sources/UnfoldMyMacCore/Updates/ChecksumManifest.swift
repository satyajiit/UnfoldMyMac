import Foundation

/// Reads the `SHA256SUMS` asset published beside each disk image.
///
/// Parsing is strict on purpose. The manifest naming a *different* file would otherwise validate a
/// download it never described, and "there is only one image per release" is a habit of the release
/// script rather than a property of the format.
public enum ChecksumManifest {
    /// The largest manifest worth reading. The real one is 88 bytes.
    public static let byteLimit = 4096

    /// The digest recorded for `asset`, or nil when the manifest is malformed or describes something else.
    public static func digest(for asset: String, in text: String) -> String? {
        guard text.utf8.count <= byteLimit else { return nil }
        var found: String?
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let entry = parse(trimmed) else { return nil }
            guard entry.name == asset else { continue }
            // A second line for the same asset means we cannot know which digest was meant.
            guard found == nil else { return nil }
            found = entry.digest
        }
        return found
    }

    /// `<64 lowercase hex>  <name>`, with the binary-mode `*` marker GNU coreutils writes.
    private static func parse(_ line: String) -> (digest: String, name: String)? {
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count == 2 else { return nil }
        let digest = fields[0]
        guard digest.count == 64, digest.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) else { return nil }
        var name = fields[1]
        if name.first == "*" { name.removeFirst() }
        guard !name.isEmpty else { return nil }
        return (String(digest), String(name))
    }
}
