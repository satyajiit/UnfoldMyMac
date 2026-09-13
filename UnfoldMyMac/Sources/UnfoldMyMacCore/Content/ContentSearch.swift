import Foundation

public enum ContentSearch {
    /// Every whitespace-delimited word must occur; matching follows the user's locale.
    public static func matches(_ query: String, fields: [String]) -> Bool {
        let haystack = fields.joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { haystack.localizedStandardContains(String($0)) }
    }
}
