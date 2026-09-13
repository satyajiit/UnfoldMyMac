import Foundation

struct NoteLine: Equatable {
    enum Kind: Equatable { case heading, bullet, body }
    let kind: Kind
    let text: String
}

/// Splits release notes into rows the view can draw, bounding the work before any parsing happens.
enum UpdateNoteParser {
    static func parse(_ notes: String, byteLimit: Int, lineLimit: Int) -> (lines: [NoteLine], truncated: Bool) {
        // Bound the input first: a pathological body must not reach the markdown parser at all.
        var text = notes
        if text.utf8.count > byteLimit { text = String(decoding: Array(text.utf8.prefix(byteLimit)), as: UTF8.self) }
        var rows: [NoteLine] = []
        var truncated = text.utf8.count < notes.utf8.count
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard rows.count < lineLimit else { truncated = true; break }
            rows.append(classify(line))
        }
        return (rows, truncated)
    }

    private static func classify(_ line: String) -> NoteLine {
        if let hash = line.prefix(6).lastIndex(of: "#"), line.hasPrefix("#") {
            let rest = line[line.index(after: hash)...].trimmingCharacters(in: .whitespaces)
            return NoteLine(kind: .heading, text: stripImages(rest))
        }
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return NoteLine(kind: .bullet, text: stripImages(String(line.dropFirst(2))))
        }
        return NoteLine(kind: .body, text: stripImages(line))
    }

    /// `![alt](url)` becomes its alt text, so notes never cause a fetch or leave a dangling link.
    private static func stripImages(_ line: String) -> String {
        line.replacing(/!\[([^\]]*)\]\([^)]*\)/) { match in String(match.output.1) }
    }
}
