import Foundation
import UnfoldMyMacCore

struct GitHubPublicEvent: Decodable, Sendable {
    let id: String
    let type: String
    let created_at: Date
}
