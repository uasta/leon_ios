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

struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T
}

private struct APIErrorEnvelope: Decodable {
    let code: Int?
    let message: String?
    let errors: [String: [String]]?

    var preferredMessage: String? {
        if let firstFieldMessage = errors?
            .values
            .lazy
            .compactMap({ $0.first })
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !firstFieldMessage.isEmpty {
            return firstFieldMessage
        }

        if let message,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
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
    case requestFailed(statusCode: Int, message: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "API 基础地址无效"
        case .invalidResponse:
            return "服务端响应格式无效"
        case .unauthorized:
            return "登录状态已失效，请重新登录"
        case let .requestFailed(_, message):
            return message
        case let .transport(error):
            return error.localizedDescription
        case let .decoding(error):
            return error.localizedDescription
        }
    }
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
            return "请求参数有误，请稍后重试"
        case 401:
            return "登录状态已失效，请重新登录"
        case 403:
            return "当前账号没有权限执行这个操作"
        case 404:
            return "请求的内容不存在"
        case 422:
            return "提交的信息有误，请检查后重试"
        case 500...599:
            return "服务暂时开小差了，请稍后再试"
        default:
            return "请求失败，请稍后重试"
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
            throw APIClientError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message: String

            if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data),
               let preferredMessage = envelope.preferredMessage {
                message = preferredMessage
            } else {
                let rawMessage = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                message = (rawMessage?.isEmpty == false ? rawMessage : nil) ?? fallbackMessage(for: httpResponse.statusCode)
            }

            throw APIClientError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(APIEnvelope<T>.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
