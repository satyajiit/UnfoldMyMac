import Foundation
import UnfoldMyMacCore

struct ClaudeCachedLog: Codable {
    let inode: UInt64
    let offset: UInt64
    let modified: Date
    let ledger: ClaudeUsageLedger
}
