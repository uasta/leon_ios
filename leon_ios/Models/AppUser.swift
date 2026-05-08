import Foundation

struct AppUser: Identifiable, Hashable, Codable {
    let id: Int
    var name: String
    var email: String
}
