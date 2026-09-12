import Foundation
import UnfoldMyMacCore

struct GitHubProfile: Decodable, Sendable {
    let login: String
    let public_repos: Int
    let followers: Int
    let following: Int
    let public_gists: Int
    let created_at: Date
}
