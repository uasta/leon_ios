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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            count = try container.decodeFlexibleInt(forKey: .count) ?? 0
            successCount = try container.decodeFlexibleInt(forKey: .successCount) ?? 0
            results = try container.decodeIfPresent([ReceiptOCRResult].self, forKey: .results) ?? []
        }
    }

    /// 对齐 `docs/前端接口对接文档.md` §8.1 小票 OCR 返回格式。
    struct ReceiptOCRResult: Decodable {
        let filename: String
        let success: Bool
        let message: String
        let id: Int?
        let parser: String?
        let platform: String?
        let confidence: Double?
        let warnings: [String]
        let data: ReceiptOCRParsedData?

        enum CodingKeys: String, CodingKey {
            case filename
            case success
            case message
            case id
            case parser
            case platform
            case confidence
            case warnings
            case data
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            filename = try container.decodeIfPresent(String.self, forKey: .filename) ?? ""
            success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
            message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
            id = try container.decodeFlexibleInt(forKey: .id)
            parser = try container.decodeIfPresent(String.self, forKey: .parser)
            platform = try container.decodeIfPresent(String.self, forKey: .platform)
            confidence = try container.decodeFlexibleDoubleIfPresent(forKey: .confidence)
            warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
            data = try container.decodeIfPresent(ReceiptOCRParsedData.self, forKey: .data)
        }
    }

    struct ReceiptOCRParsedData: Decodable {
        let platform: String?
        let orderStatus: String?
        let totalAmount: Double?
        let items: [ReceiptOCRItem]
        let imagePath: String?
        let rawText: String?
        let elapsedMs: Double?

        enum CodingKeys: String, CodingKey {
            case platform
            case orderStatus = "order_status"
            case totalAmount = "total_amount"
            case items
            case imagePath = "image_path"
            case rawText = "raw_text"
            case elapsedMs = "elapsed_ms"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            platform = try container.decodeIfPresent(String.self, forKey: .platform)
            orderStatus = try container.decodeIfPresent(String.self, forKey: .orderStatus)
            // 后端可能返回数字或字符串（如 "31.59" / "¥5.99"）
            totalAmount = try container.decodeFlexibleDoubleIfPresent(forKey: .totalAmount)
            items = try container.decodeIfPresent([ReceiptOCRItem].self, forKey: .items) ?? []
            imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
            rawText = try container.decodeIfPresent(String.self, forKey: .rawText)
            elapsedMs = try container.decodeFlexibleDoubleIfPresent(forKey: .elapsedMs)
        }
    }

    struct ReceiptOCRItem: Decodable, Hashable {
        let name: String
        let unitPrice: Double?
        let quantity: Double
        let actualPrice: Double?
        let refund: Double?
        let rawLines: [String]

        enum CodingKeys: String, CodingKey {
            case name
            case unitPrice = "unit_price"
            case quantity
            case actualPrice = "actual_price"
            case refund
            case rawLines = "raw_lines"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            // items 透传 Python 原始 parsed_data，价格字段常为字符串
            unitPrice = try container.decodeFlexibleDoubleIfPresent(forKey: .unitPrice)
            quantity = try container.decodeFlexibleDoubleIfPresent(forKey: .quantity) ?? 1
            actualPrice = try container.decodeFlexibleDoubleIfPresent(forKey: .actualPrice)
            refund = try container.decodeFlexibleDoubleIfPresent(forKey: .refund)
            rawLines = try container.decodeIfPresent([String].self, forKey: .rawLines) ?? []
        }
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

    struct ReceiptOCRImportPayload {
        let envelope: APIEnvelope<ReceiptOCRImportResponse>
        let rawJSON: String
    }

    func importReceiptOCR(
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> ReceiptOCRImportPayload {
        let file = MultipartFormFile(
            name: "images[]",
            filename: filename,
            mimeType: mimeType,
            data: imageData
        )
        // enable_llm_fallback / include_ocr_lines 为可选，默认 false；
        // multipart 传字符串 "false" 会被 Laravel boolean 校验拒绝，故不传。
        let uploaded = try await client.uploadWithRaw(
            path: "api/v1/ingredients/import/receipt-ocr",
            files: [file],
            as: ReceiptOCRImportResponse.self
        )
        return ReceiptOCRImportPayload(envelope: uploaded.envelope, rawJSON: uploaded.rawJSON)
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

struct ReceiptOCRSummary: Hashable {
    var platform: String?
    var orderStatus: String?
    var totalAmount: Double?
    var confidence: Double?
}

struct ReceiptOCRCandidate: Identifiable, Hashable {
    let id: UUID
    var name: String
    var quantity: Double
    var actualPrice: Double?
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        actualPrice: Double? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.actualPrice = actualPrice
        self.isSelected = isSelected
    }

    static func flatten(from response: IngredientService.ReceiptOCRImportResponse) -> (
        candidates: [ReceiptOCRCandidate],
        summary: ReceiptOCRSummary?,
        errorMessage: String?
    ) {
        var candidates: [ReceiptOCRCandidate] = []
        var failureMessages: [String] = []
        var summary: ReceiptOCRSummary?

        for result in response.results {
            if result.success, let data = result.data {
                if summary == nil {
                    summary = ReceiptOCRSummary(
                        platform: result.platform ?? data.platform,
                        orderStatus: data.orderStatus,
                        totalAmount: data.totalAmount,
                        confidence: result.confidence
                    )
                }

                for item in data.items {
                    let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    candidates.append(
                        ReceiptOCRCandidate(
                            name: trimmed,
                            quantity: item.quantity > 0 ? item.quantity : 1,
                            actualPrice: item.actualPrice
                        )
                    )
                }
            } else if !result.success {
                let message = result.message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !message.isEmpty {
                    failureMessages.append(message)
                }
            }
        }

        let errorMessage = candidates.isEmpty ? failureMessages.first : nil
        return (candidates, summary, errorMessage)
    }
}

// MARK: - Flexible number decoding

private extension KeyedDecodingContainer {
    /// 兼容后端返回 Double / Int / String（含货币符号）的数字字段。
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if !contains(key) {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decode(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let filtered = trimmed.replacingOccurrences(
                of: "[^0-9.\\-]",
                with: "",
                options: .regularExpression
            )
            return Double(filtered)
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let double = try decodeFlexibleDoubleIfPresent(forKey: key) {
            return Int(double.rounded())
        }
        return nil
    }
}
