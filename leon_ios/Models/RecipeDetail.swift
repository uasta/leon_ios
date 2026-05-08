import Foundation

struct RecipeDetail: Identifiable, Hashable, Codable {
    let id: Int
    var title: String
    var coverURL: String?
    var ingredients: [String]
    var steps: [String]
    var liked: Bool
    var favorited: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverURL = "cover_url"
        case ingredients
        case steps
        case liked
        case favorited
    }
}
