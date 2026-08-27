import Foundation

struct RecipeSummary: Identifiable, Hashable, Codable {
    let id: Int
    var title: String
    var coverURL: String?
    var matchReason: String?
    var heat: Int?
    var liked: Bool
    var favorited: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverURL = "cover_url"
        case matchReason = "match_reason"
        case heat
        case liked
        case favorited
    }
}
