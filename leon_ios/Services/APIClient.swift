import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
    case put = "PUT"
}

struct APIRequest {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data? = nil
}

struct MultipartFormFile {
    let name: String
    let filename: String
    let mimeType: String
    let data: Data
}

struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T
}

private struct APIErrorEnvelope: Decodable {
    let code: Int?
    let message: String?
    let errors: [String: [String]]?

    /// 展示优先用顶层 message；字段错误可作为补充（校验场景）。
    var preferredMessage: String? {
        if let message,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let firstFieldMessage = errors?
                .values
                .lazy
                .compactMap({ $0.first })
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !firstFieldMessage.isEmpty,
               firstFieldMessage != message {
                return firstFieldMessage
            }
            return message
        }

        if let firstFieldMessage = errors?
            .values
            .lazy
            .compactMap({ $0.first })
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !firstFieldMessage.isEmpty {
            return firstFieldMessage
        }

        return nil
    }
}

struct EmptyPayload: Decodable {
    init() {}

    init(from decoder: Decoder) throws {}
}

enum APIClientError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case unauthorized
    case requestFailed(statusCode: Int, code: Int?, message: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return L10n.text(L10n.ClientError.invalidBaseURL)
        case .invalidResponse:
            return L10n.text(L10n.ClientError.invalidResponse)
        case .unauthorized:
            return L10n.text(L10n.ClientError.unauthorized)
        case let .requestFailed(_, _, message):
            return message
        case let .transport(error):
            return error.localizedDescription
        case let .decoding(error):
            return error.localizedDescription
        }
    }

    var businessCode: Int? {
        switch self {
        case let .requestFailed(_, code, _):
            return code
        case .unauthorized:
            return APIBusinessCode.unauthenticated
        default:
            return nil
        }
    }
}

extension Notification.Name {
    static let leonSessionUnauthorized = Notification.Name("leon.session.unauthorized")
}

actor APIClient {
    let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    init(
        baseURL: URL? = APIClient.defaultBaseURL,
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () -> String? = {
            UserDefaults.standard.string(forKey: "session.accessToken")
        }
    ) {
        self.baseURL = baseURL ?? URL(fileURLWithPath: "/invalid-base-url")
        self.session = session
        self.tokenProvider = tokenProvider
    }

    static var defaultBaseURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "LEON_API_BASE_URL") as? String,
           let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
           let url = URL(string: trimmed) {
            return url
        }

        return URL(string: "http://120.24.29.178")
    }

    private func fallbackMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return L10n.text(L10n.ClientError.badRequest)
        case 401:
            return L10n.text(L10n.ClientError.unauthorized)
        case 403:
            return L10n.text(L10n.ClientError.forbidden)
        case 404:
            return L10n.text(L10n.ClientError.notFound)
        case 422:
            return L10n.text(L10n.ClientError.validation)
        case 500...599:
            return L10n.text(L10n.ClientError.server)
        default:
            return L10n.text(L10n.ClientError.generic)
        }
    }

    func send<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> APIEnvelope<T> {
        guard baseURL.isFileURL == false else {
            throw APIClientError.invalidBaseURL
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)
        if !request.queryItems.isEmpty {
            components?.queryItems = request.queryItems
        }

        guard let url = components?.url else {
            throw APIClientError.invalidBaseURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(Self.preferredLocaleTag, forHTTPHeaderField: "Accept-Language")
        urlRequest.setValue(Self.preferredLocaleTag, forHTTPHeaderField: "X-Locale")

        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let token = tokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIClientError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            UserDefaults.standard.removeObject(forKey: "session.accessToken")
            NotificationCenter.default.post(name: .leonSessionUnauthorized, object: nil)
            throw APIClientError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            let message: String

            if let preferredMessage = envelope?.preferredMessage {
                message = preferredMessage
            } else {
                let rawMessage = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                message = (rawMessage?.isEmpty == false ? rawMessage : nil) ?? fallbackMessage(for: httpResponse.statusCode)
            }

            throw APIClientError.requestFailed(
                statusCode: httpResponse.statusCode,
                code: envelope?.code,
                message: message
            )
        }

        do {
            return try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    struct UploadPayload<T: Decodable> {
        let envelope: APIEnvelope<T>
        /// 接口原始响应正文（尽量 pretty-print），便于调试复制。
        let rawJSON: String
    }

    /// multipart/form-data 上传（如 OCR `images[]`）。
    func upload<T: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        queryItems: [URLQueryItem] = [],
        fields: [String: String] = [:],
        files: [MultipartFormFile],
        as type: T.Type
    ) async throws -> APIEnvelope<T> {
        try await uploadWithRaw(
            path: path,
            method: method,
            queryItems: queryItems,
            fields: fields,
            files: files,
            as: type
        ).envelope
    }

    /// 同上，额外返回原始 JSON 正文。
    func uploadWithRaw<T: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        queryItems: [URLQueryItem] = [],
        fields: [String: String] = [:],
        files: [MultipartFormFile],
        as type: T.Type
    ) async throws -> UploadPayload<T> {
        guard baseURL.isFileURL == false else {
            throw APIClientError.invalidBaseURL
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIClientError.invalidBaseURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = Self.makeMultipartBody(boundary: boundary, fields: fields, files: files)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(Self.preferredLocaleTag, forHTTPHeaderField: "Accept-Language")
        urlRequest.setValue(Self.preferredLocaleTag, forHTTPHeaderField: "X-Locale")
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = tokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIClientError.transport(error)
        }

        let rawJSON = Self.prettyJSONString(from: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            UserDefaults.standard.removeObject(forKey: "session.accessToken")
            NotificationCenter.default.post(name: .leonSessionUnauthorized, object: nil)
            throw APIClientError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            let message: String

            if let preferredMessage = envelope?.preferredMessage {
                message = preferredMessage
            } else {
                let rawMessage = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                message = (rawMessage?.isEmpty == false ? rawMessage : nil) ?? fallbackMessage(for: httpResponse.statusCode)
            }

            throw APIClientError.requestFailed(
                statusCode: httpResponse.statusCode,
                code: envelope?.code,
                message: message
            )
        }

        do {
            let envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
            return UploadPayload(envelope: envelope, rawJSON: rawJSON)
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    private static func prettyJSONString(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        files: [MultipartFormFile]
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for (name, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }

        for file in files {
            body.append("--\(boundary)\(lineBreak)")
            body.append(
                "Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\(lineBreak)"
            )
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.append(lineBreak)
        }

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    /// 后端目前支持 zh / en；优先使用 App 内语言设置。
    private static var preferredLocaleTag: String {
        LanguageStore.currentAPILocaleTag()
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
