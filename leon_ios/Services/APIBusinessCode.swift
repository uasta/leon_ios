import Foundation

/// 与后端 `App\Support\ApiCode` 保持同步。
/// 前端优先用 code 做分支，message 只负责展示。
enum APIBusinessCode {
    static let ok = 0

    static let badRequest = 40000
    static let unauthenticated = 40100
    static let forbidden = 40300
    static let notFound = 40400
    static let validationFailed = 42200
    static let tooManyRequests = 42900
    static let serverError = 50000

    static let authInvalidCredentials = 40101
    static let authEmailUnverified = 40102
    static let authEmailAlreadyVerified = 40103
    static let authPasswordResetInvalid = 40104
    static let authPasswordResetExpired = 40105
    static let authUserNotFound = 40106
}
