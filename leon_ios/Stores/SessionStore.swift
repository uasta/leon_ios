import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    enum AuthStatus: String {
        case anonymous
        case authenticated
    }

    @Published private(set) var authStatus: AuthStatus
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var accessToken: String?

    private let tokenKey = "session.accessToken"

    init() {
        let persistedToken = UserDefaults.standard.string(forKey: tokenKey)
        self.accessToken = persistedToken
        self.authStatus = persistedToken == nil ? .anonymous : .authenticated
        self.currentUser = nil
    }

    var isAuthenticated: Bool {
        authStatus == .authenticated
    }

    func configureAuthenticatedSession(user: AppUser, token: String) {
        currentUser = user
        accessToken = token
        authStatus = .authenticated
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    func updateCurrentUser(_ user: AppUser?) {
        currentUser = user
    }

    func clearSession() {
        currentUser = nil
        accessToken = nil
        authStatus = .anonymous
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
