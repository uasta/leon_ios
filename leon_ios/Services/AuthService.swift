import Foundation

actor AuthService {
    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }

    struct RegisterRequest: Encodable {
        let name: String
        let email: String
        let password: String
        let passwordConfirmation: String

        enum CodingKeys: String, CodingKey {
            case name
            case email
            case password
            case passwordConfirmation = "password_confirmation"
        }
    }

    struct LoginResponse: Decodable {
        let user: AppUser
        let token: String
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case user
            case token
            case tokenType = "token_type"
        }
    }

    struct RegisterResponse: Decodable {
        let user: AppUser
    }

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func login(email: String, password: String) async throws -> APIEnvelope<LoginResponse> {
        let body = try JSONEncoder().encode(
            LoginRequest(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        )
        let request = APIRequest(
            path: "api/login",
            method: .post,
            body: body
        )
        return try await client.send(request, as: LoginResponse.self)
    }

    func register(name: String, email: String, password: String, passwordConfirmation: String) async throws -> APIEnvelope<RegisterResponse> {
        let body = try JSONEncoder().encode(
            RegisterRequest(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                passwordConfirmation: passwordConfirmation
            )
        )
        let request = APIRequest(
            path: "api/register",
            method: .post,
            body: body
        )
        return try await client.send(request, as: RegisterResponse.self)
    }

    func fetchCurrentUser() async throws -> APIEnvelope<AppUser> {
        try await client.send(APIRequest(path: "api/user"), as: AppUser.self)
    }

    func logout() async throws -> APIEnvelope<EmptyPayload> {
        try await client.send(APIRequest(path: "api/logout", method: .post), as: EmptyPayload.self)
    }
}
