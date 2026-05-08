import Foundation

actor IngredientService {
    struct RemoteIngredient: Decodable {
        let id: Int
        let name: String
        let quantity: Double?
        let unit: String
        let note: String
    }

    struct ReceiptOCRImportResponse: Decodable {
        let count: Int
        let successCount: Int
        let results: [ReceiptOCRResult]

        enum CodingKeys: String, CodingKey {
            case count
            case successCount = "success_count"
            case results
        }
    }

    struct ReceiptOCRResult: Decodable {
        let filename: String
        let success: Bool
        let message: String
        let id: Int
    }

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchIngredients(keyword: String? = nil) async throws -> APIEnvelope<[RemoteIngredient]> {
        var request = APIRequest(path: "api/v1/ingredients")
        if let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        }
        return try await client.send(request, as: [RemoteIngredient].self)
    }

    func fetchSuggestions(keyword: String) async throws -> APIEnvelope<[String]> {
        let request = APIRequest(
            path: "api/v1/ingredients/suggestions",
            queryItems: [URLQueryItem(name: "keyword", value: keyword)]
        )
        return try await client.send(request, as: [String].self)
    }

    func bootstrapLocalIngredients(_ drafts: [IngredientSyncDraft]) async throws -> APIEnvelope<BootstrapResponse> {
        let body = try JSONEncoder().encode(BootstrapRequest(ingredients: drafts))
        let request = APIRequest(
            path: "api/v1/sync/bootstrap",
            method: .post,
            body: body
        )
        return try await client.send(request, as: BootstrapResponse.self)
    }
}

extension IngredientService {
    struct BootstrapRequest: Encodable {
        let ingredients: [IngredientSyncDraft]
    }

    struct BootstrapResponse: Decodable {
        let syncedCount: Int
        let createdCount: Int
        let updatedCount: Int
        let ingredients: [RemoteIngredient]

        enum CodingKeys: String, CodingKey {
            case syncedCount = "synced_count"
            case createdCount = "created_count"
            case updatedCount = "updated_count"
            case ingredients
        }
    }
}
