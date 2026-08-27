import Foundation

struct RecipeDetail: Identifiable, Hashable, Codable {
    let id: Int
    var title: String
    var coverURL: String?
    var ingredients: [String]
    var steps: [RecipeStep]
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

    init(
        id: Int,
        title: String,
        coverURL: String? = nil,
        ingredients: [String],
        steps: [RecipeStep],
        liked: Bool,
        favorited: Bool
    ) {
        self.id = id
        self.title = title
        self.coverURL = coverURL
        self.ingredients = ingredients
        self.steps = steps
        self.liked = liked
        self.favorited = favorited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        coverURL = try container.decodeIfPresent(String.self, forKey: .coverURL)
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        liked = try container.decodeIfPresent(Bool.self, forKey: .liked) ?? false
        favorited = try container.decodeIfPresent(Bool.self, forKey: .favorited) ?? false

        if let structuredSteps = try? container.decode([RecipeStep].self, forKey: .steps) {
            steps = structuredSteps.enumerated().map { offset, step in
                RecipeStep(
                    index: step.index > 0 ? step.index : offset + 1,
                    text: step.text,
                    imageURL: step.imageURL
                )
            }
        } else if let plainSteps = try? container.decode([String].self, forKey: .steps) {
            steps = plainSteps.enumerated().map { index, text in
                RecipeStep(index: index + 1, text: text)
            }
        } else {
            steps = []
        }
    }
}
