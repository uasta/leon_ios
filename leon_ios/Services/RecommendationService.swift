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

    struct DailyRecommendationResponse: Decodable {
        let date: String
        let batch: Int?
        let items: [RecipeSummary]
        let featured: RecipeSummary?
        let alternatives: [RecipeSummary]
        let preferredFlavors: [String]

        enum CodingKeys: String, CodingKey {
            case date
            case batch
            case items
            case featured
            case alternatives
            case preferredFlavors = "preferred_flavors"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(String.self, forKey: .date)
            batch = try container.decodeIfPresent(Int.self, forKey: .batch)
            preferredFlavors = (try? container.decode([String].self, forKey: .preferredFlavors)) ?? []
            featured = try container.decodeIfPresent(RecipeSummary.self, forKey: .featured)
            alternatives = (try? container.decode([RecipeSummary].self, forKey: .alternatives)) ?? []

            if let decodedItems = try? container.decode([RecipeSummary].self, forKey: .items), !decodedItems.isEmpty {
                items = decodedItems
            } else if let featured {
                items = [featured] + alternatives
            } else {
                items = alternatives
            }
        }

        /// 统一给 UI 用的今日推荐列表。
        var displayItems: [RecipeSummary] {
            if !items.isEmpty { return items }
            if let featured { return [featured] + alternatives }
            return alternatives
        }
    }

    struct RecommendationFeedPage: Decodable {
        let items: [RecipeSummary]
        let page: Int
        let limit: Int
        let hasMore: Bool
        let seed: Int

        enum CodingKeys: String, CodingKey {
            case items
            case page
            case limit
            case hasMore = "has_more"
            case seed
        }

        init(items: [RecipeSummary], page: Int, limit: Int, hasMore: Bool, seed: Int = 0) {
            self.items = items
            self.page = page
            self.limit = limit
            self.hasMore = hasMore
            self.seed = seed
        }

        init(from decoder: Decoder) throws {
            if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
               let items = try? keyed.decode([RecipeSummary].self, forKey: .items) {
                self.items = items
                self.page = (try? keyed.decode(Int.self, forKey: .page)) ?? 1
                self.limit = (try? keyed.decode(Int.self, forKey: .limit)) ?? items.count
                self.hasMore = (try? keyed.decode(Bool.self, forKey: .hasMore)) ?? false
                self.seed = (try? keyed.decode(Int.self, forKey: .seed)) ?? 0
                return
            }

            let legacyItems = try [RecipeSummary](from: decoder)
            self.items = legacyItems
            self.page = 1
            self.limit = legacyItems.count
            self.hasMore = false
            self.seed = 0
        }
    }

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchRecommendationFeed(page: Int = 1, limit: Int = 20, seed: Int = 0) async throws -> APIEnvelope<RecommendationFeedPage> {
        try await client.send(
            APIRequest(
                path: "api/v1/recommendations/feed",
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "seed", value: String(max(0, seed))),
                ]
            ),
            as: RecommendationFeedPage.self
        )
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

    func fetchSearchSuggestions(query: String) async throws -> APIEnvelope<[String]> {
        let request = APIRequest(
            path: "api/v1/recipes/suggest",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        return try await client.send(request, as: [String].self)
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

    func fetchDailyRecommendation(
        date: String? = nil,
        ingredients: [String] = [],
        limit: Int = 6,
        batch: Int = 0
    ) async throws -> APIEnvelope<DailyRecommendationResponse> {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "batch", value: String(max(0, batch))),
        ]
        if let date, !date.isEmpty {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        for name in ingredients.prefix(20) {
            queryItems.append(URLQueryItem(name: "ingredients[]", value: name))
        }

        return try await client.send(
            APIRequest(
                path: "api/v1/recommendations/daily",
                queryItems: queryItems
            ),
            as: DailyRecommendationResponse.self
        )
    }
}
