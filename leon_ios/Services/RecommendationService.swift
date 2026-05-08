import Foundation

actor RecommendationService {
    struct HotSearchItem: Decodable {
        let keyword: String
    }

    struct SearchRecipesResponse: Decodable {
        let query: String
        let recipes: [RecipeSummary]
        let total: Int
    }

    struct ByIngredientsRequest: Encodable {
        let ingredients: [String]
    }

    struct ByIngredientsResponse: Decodable {
        let ingredients: [String]
        let recipes: [RecipeSummary]
    }

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchRecommendationFeed() async throws -> APIEnvelope<[RecipeSummary]> {
        try await client.send(APIRequest(path: "api/v1/recommendations/feed"), as: [RecipeSummary].self)
    }

    func fetchHotSearches() async throws -> APIEnvelope<[HotSearchItem]> {
        try await client.send(APIRequest(path: "api/v1/recipes/hot-searches"), as: [HotSearchItem].self)
    }

    func searchRecipes(query: String) async throws -> APIEnvelope<SearchRecipesResponse> {
        let request = APIRequest(
            path: "api/v1/recipes/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        return try await client.send(request, as: SearchRecipesResponse.self)
    }

    func fetchRecipeDetail(id: Int) async throws -> APIEnvelope<RecipeDetail> {
        try await client.send(APIRequest(path: "api/v1/recipes/\(id)"), as: RecipeDetail.self)
    }

    func fetchByIngredients(_ ingredientNames: [String]) async throws -> APIEnvelope<ByIngredientsResponse> {
        let normalized = Array(Set(
            ingredientNames
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )).sorted()

        let body = try JSONEncoder().encode(ByIngredientsRequest(ingredients: normalized))
        let request = APIRequest(
            path: "api/v1/recommendations/by-ingredients",
            method: .post,
            body: body
        )
        return try await client.send(request, as: ByIngredientsResponse.self)
    }
}
