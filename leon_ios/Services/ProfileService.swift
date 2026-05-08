import Foundation

actor ProfileService {
    struct RecipeBehaviorRequest: Encodable {
        let title: String?
        let coverURL: String?
        let matchReason: String?

        enum CodingKeys: String, CodingKey {
            case title
            case coverURL = "cover_url"
            case matchReason = "match_reason"
        }
    }

    struct ToggleLikeRequest: Encodable {
        let liked: Bool
        let title: String?
        let coverURL: String?
        let matchReason: String?

        enum CodingKeys: String, CodingKey {
            case liked
            case title
            case coverURL = "cover_url"
            case matchReason = "match_reason"
        }
    }

    struct ToggleFavoriteRequest: Encodable {
        let favorited: Bool
    }

    struct BehaviorStateResponse: Decodable {
        let recipeID: Int
        let liked: Bool?
        let favorited: Bool?

        enum CodingKeys: String, CodingKey {
            case recipeID = "recipe_id"
            case liked
            case favorited
        }
    }

    struct HistoryRecordResponse: Decodable {
        let recipeID: Int
        let recorded: Bool
        let viewedAt: String?

        enum CodingKeys: String, CodingKey {
            case recipeID = "recipe_id"
            case recorded
            case viewedAt = "viewed_at"
        }
    }

    struct PreferenceResponse: Decodable {
        let tabOrder: [AppTab]

        enum CodingKeys: String, CodingKey {
            case tabOrder = "tab_order"
        }
    }

    struct PreferenceRequest: Encodable {
        let tabOrder: [AppTab]

        enum CodingKeys: String, CodingKey {
            case tabOrder = "tab_order"
        }
    }

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchLikes() async throws -> APIEnvelope<[RecipeSummary]> {
        try await client.send(APIRequest(path: "api/v1/me/likes/recipes"), as: [RecipeSummary].self)
    }

    func fetchFavorites() async throws -> APIEnvelope<[RecipeSummary]> {
        try await client.send(APIRequest(path: "api/v1/me/favorites/recipes"), as: [RecipeSummary].self)
    }

    func fetchHistory() async throws -> APIEnvelope<[RecipeSummary]> {
        try await client.send(APIRequest(path: "api/v1/me/history/recipes"), as: [RecipeSummary].self)
    }

    func fetchPreferences() async throws -> APIEnvelope<PreferenceResponse> {
        try await client.send(APIRequest(path: "api/v1/me/preferences"), as: PreferenceResponse.self)
    }

    func updatePreferences(tabOrder: [AppTab]) async throws -> APIEnvelope<PreferenceResponse> {
        let body = try JSONEncoder().encode(PreferenceRequest(tabOrder: tabOrder))
        let request = APIRequest(
            path: "api/v1/me/preferences",
            method: .put,
            body: body
        )
        return try await client.send(request, as: PreferenceResponse.self)
    }

    func toggleLike(recipe: RecipeSummary, liked: Bool) async throws -> APIEnvelope<BehaviorStateResponse> {
        let body = try JSONEncoder().encode(
            ToggleLikeRequest(
                liked: liked,
                title: recipe.title,
                coverURL: recipe.coverURL,
                matchReason: recipe.matchReason
            )
        )
        let request = APIRequest(
            path: "api/v1/recipes/\(recipe.id)/like",
            method: .post,
            body: body
        )
        return try await client.send(request, as: BehaviorStateResponse.self)
    }

    func toggleFavorite(recipeID: Int, favorited: Bool) async throws -> APIEnvelope<BehaviorStateResponse> {
        let body = try JSONEncoder().encode(ToggleFavoriteRequest(favorited: favorited))
        let request = APIRequest(
            path: "api/v1/recipes/\(recipeID)/favorite",
            method: .post,
            body: body
        )
        return try await client.send(request, as: BehaviorStateResponse.self)
    }

    func recordHistory(recipe: RecipeSummary) async throws -> APIEnvelope<HistoryRecordResponse> {
        let body = try JSONEncoder().encode(
            RecipeBehaviorRequest(
                title: recipe.title,
                coverURL: recipe.coverURL,
                matchReason: recipe.matchReason
            )
        )
        let request = APIRequest(
            path: "api/v1/recipes/\(recipe.id)/history",
            method: .post,
            body: body
        )
        return try await client.send(request, as: HistoryRecordResponse.self)
    }
}
