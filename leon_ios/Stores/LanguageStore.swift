import Foundation
import Combine

/// App 语言偏好（可跟随系统，也可手动固定）。
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var titleKey: LocalizedStringResource {
        switch self {
        case .system:
            return L10n.Settings.languageSystem
        case .zhHans:
            return L10n.Settings.languageChinese
        case .english:
            return L10n.Settings.languageEnglish
        }
    }

    /// 解析后的展示 Locale（供 SwiftUI / L10n 使用）。
    var resolvedLocale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    /// 发给后端的语言标签。
    var apiLocaleTag: String {
        switch self {
        case .system:
            let language = Locale.current.language.languageCode?.identifier ?? "zh"
            if language.lowercased().hasPrefix("zh") {
                return "zh-CN"
            }
            if language.lowercased().hasPrefix("en") {
                return "en"
            }
            return "zh-CN"
        case .zhHans:
            return "zh-CN"
        case .english:
            return "en"
        }
    }
}

/// 语言偏好存储。UI 通过 `@EnvironmentObject` 观察；`L10n` / `APIClient` 可直接读 UserDefaults。
@MainActor
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()
    static let storageKey = "settings.appLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: raw) ?? .system
    }

    var resolvedLocale: Locale {
        language.resolvedLocale
    }

    var apiLocaleTag: String {
        language.apiLocaleTag
    }

    /// 供非 MainActor 上下文（如 APIClient）读取。
    nonisolated static func currentAPILocaleTag() -> String {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        let language = AppLanguage(rawValue: raw) ?? .system
        return language.apiLocaleTag
    }

    nonisolated static func currentResolvedLocale() -> Locale {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        let language = AppLanguage(rawValue: raw) ?? .system
        return language.resolvedLocale
    }
}
