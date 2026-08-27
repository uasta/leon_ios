import Foundation
import SwiftUI

/// App 本地化入口。
///
/// - 文案定义在 `Localizable.xcstrings`（Apple String Catalog）
/// - 代码里通过 `L10n.*` 引用，避免散落硬编码
/// - 新增语言：在 Xcode 给 Catalog 加 localization，并更新 `project.pbxproj` 的 `knownRegions`
enum L10n {
    // MARK: - Helpers

    static func text(_ key: LocalizedStringResource) -> String {
        var resource = key
        resource.locale = LanguageStore.currentResolvedLocale()
        return String(localized: resource)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let locale = LanguageStore.currentResolvedLocale()
        var resource = LocalizedStringResource(String.LocalizationValue(key))
        resource.locale = locale
        let format = String(localized: resource)
        return String(format: format, locale: locale, arguments: arguments)
    }

    // MARK: - Common

    enum Common {
        static let close = LocalizedStringResource("common.close", defaultValue: "关闭")
        static let retry = LocalizedStringResource("common.retry", defaultValue: "重试")
        static let confirm = LocalizedStringResource("common.confirm", defaultValue: "确认")
        static let cancel = LocalizedStringResource("common.cancel", defaultValue: "取消")
        static let notConfigured = LocalizedStringResource("common.not_configured", defaultValue: "未配置")
        static let fromAccountBehavior = LocalizedStringResource(
            "common.from_account_behavior",
            defaultValue: "来自账号行为记录"
        )
    }

    // MARK: - Tabs

    enum Tab {
        static let ingredients = LocalizedStringResource("tab.ingredients", defaultValue: "食材")
        static let recommend = LocalizedStringResource("tab.recommend", defaultValue: "推荐")
        static let explore = LocalizedStringResource("tab.explore", defaultValue: "开拓")
        static let me = LocalizedStringResource("tab.me", defaultValue: "我的")
    }

    // MARK: - Auth

    enum Auth {
        static let login = LocalizedStringResource("auth.login", defaultValue: "登录")
        static let register = LocalizedStringResource("auth.register", defaultValue: "注册")
        static let loginRegister = LocalizedStringResource("auth.login_register", defaultValue: "登录 / 注册")
        static let logout = LocalizedStringResource("auth.logout", defaultValue: "退出登录")
        static let loggingOut = LocalizedStringResource("auth.logging_out", defaultValue: "正在退出")
        static let restoringSession = LocalizedStringResource(
            "auth.restoring_session",
            defaultValue: "正在恢复登录状态"
        )
        static let preparingAccount = LocalizedStringResource(
            "auth.preparing_account",
            defaultValue: "登录状态已存在，正在准备账号信息。"
        )

        static let loginTitle = LocalizedStringResource("auth.login_title", defaultValue: "回来做饭了？")
        static let registerTitle = LocalizedStringResource("auth.register_title", defaultValue: "给你的厨房安个家")
        static let loginSubtitle = LocalizedStringResource(
            "auth.login_subtitle",
            defaultValue: "登录一下，冰箱里的食材和口味都还在。"
        )
        static let registerSubtitle = LocalizedStringResource(
            "auth.register_subtitle",
            defaultValue: "花半分钟填一下，之后想吃什么都更好找。"
        )

        static let name = LocalizedStringResource("auth.field.name", defaultValue: "怎么称呼你")
        static let namePrompt = LocalizedStringResource("auth.field.name_prompt", defaultValue: "比如小李、阿宁")
        static let email = LocalizedStringResource("auth.field.email", defaultValue: "邮箱")
        static let emailPrompt = LocalizedStringResource("auth.field.email_prompt", defaultValue: "你常用的邮箱")
        static let password = LocalizedStringResource("auth.field.password", defaultValue: "密码")
        static let passwordPrompt = LocalizedStringResource("auth.field.password_prompt", defaultValue: "输入密码")
        static let passwordPromptRegister = LocalizedStringResource(
            "auth.field.password_prompt_register",
            defaultValue: "设个至少 6 位的密码"
        )
        static let passwordConfirm = LocalizedStringResource("auth.field.password_confirm", defaultValue: "再确认一次")
        static let passwordConfirmPrompt = LocalizedStringResource(
            "auth.field.password_confirm_prompt",
            defaultValue: "再输一遍就好"
        )

        static let forgotPassword = LocalizedStringResource("auth.forgot_password", defaultValue: "想不起来密码？")
        static let goRegister = LocalizedStringResource("auth.go_register", defaultValue: "还没有账号？一起来")
        static let goLogin = LocalizedStringResource("auth.go_login", defaultValue: "已经有账号了？直接登录")
        static let loginAction = LocalizedStringResource("auth.login_action", defaultValue: "进入厨房")
        static let registerAction = LocalizedStringResource("auth.register_action", defaultValue: "开始做饭")

        static let loginBenefitsTitle = LocalizedStringResource(
            "auth.benefits.login_title",
            defaultValue: "登录后会发生什么"
        )
        static let registerBenefitsTitle = LocalizedStringResource(
            "auth.benefits.register_title",
            defaultValue: "注册后下一步"
        )
        static let benefitSyncIngredients = LocalizedStringResource(
            "auth.benefits.sync_ingredients",
            defaultValue: "同步本地食材到账号"
        )
        static let benefitSyncTabs = LocalizedStringResource(
            "auth.benefits.sync_tabs",
            defaultValue: "同步当前 Tab 顺序偏好"
        )
        static let benefitPullBehavior = LocalizedStringResource(
            "auth.benefits.pull_behavior",
            defaultValue: "拉取点赞、收藏和浏览历史"
        )

        static let verifyTitle = LocalizedStringResource("auth.verify.title", defaultValue: "去邮箱完成验证")
        static let verifyGoLogin = LocalizedStringResource("auth.verify.go_login", defaultValue: "我已验证，去登录")
        static let verifyResend = LocalizedStringResource(
            "auth.verify.resend",
            defaultValue: "没收到？重新发送验证邮件"
        )
        static let verifyStep1 = LocalizedStringResource(
            "auth.verify.step1",
            defaultValue: "打开邮箱，找到来自 Leon 的验证邮件"
        )
        static let verifyStep2 = LocalizedStringResource(
            "auth.verify.step2",
            defaultValue: "点击邮件中的验证链接"
        )
        static let verifyStep3 = LocalizedStringResource(
            "auth.verify.step3",
            defaultValue: "回到这里登录账号"
        )
        static let verifyMailSent = LocalizedStringResource(
            "auth.verify.mail_sent",
            defaultValue: "验证邮件已发送，请查收邮箱。"
        )

        static let resetTitle = LocalizedStringResource("auth.reset.title", defaultValue: "重置密码")
        static let resetSubtitle = LocalizedStringResource(
            "auth.reset.subtitle",
            defaultValue: "输入注册邮箱，我们会发送一封重置链接。打开邮件后即可设置新密码。"
        )
        static let resetSend = LocalizedStringResource("auth.reset.send", defaultValue: "发送重置邮件")
        static let resetBackLogin = LocalizedStringResource("auth.reset.back_login", defaultValue: "返回登录")
        static let resetSentTitle = LocalizedStringResource("auth.reset.sent_title", defaultValue: "请查收重置邮件")
        static let resetResend = LocalizedStringResource(
            "auth.reset.resend",
            defaultValue: "没收到？重新发送重置邮件"
        )
        static let resetStep1 = LocalizedStringResource(
            "auth.reset.step1",
            defaultValue: "打开邮箱，找到重置密码邮件"
        )
        static let resetStep2 = LocalizedStringResource(
            "auth.reset.step2",
            defaultValue: "在网页中设置新密码"
        )
        static let resetStep3 = LocalizedStringResource(
            "auth.reset.step3",
            defaultValue: "回到 App 用新密码登录"
        )
        static let passwordMismatch = LocalizedStringResource(
            "auth.password_mismatch",
            defaultValue: "两次输入的密码不一致"
        )
        static let invalidEmail = LocalizedStringResource(
            "auth.invalid_email",
            defaultValue: "请输入有效的邮箱地址"
        )

        static func verifySubtitle(email: String) -> String {
            L10n.format("auth.verify.subtitle", email)
        }

        static func resetSentSubtitle(email: String) -> String {
            L10n.format("auth.reset.sent_subtitle", email)
        }

        static func resendCountdown(_ seconds: Int) -> String {
            L10n.format("auth.resend_countdown", seconds)
        }

        static func defaultVerificationResent() -> String {
            text(LocalizedStringResource(
                "auth.verify.resent_default",
                defaultValue: "验证邮件已重新发送，请查收。"
            ))
        }

        static func defaultPasswordResetSent() -> String {
            text(LocalizedStringResource(
                "auth.reset.sent_default",
                defaultValue: "若该邮箱已注册，重置邮件已发送。"
            ))
        }

        static func syncIngredientsOK(_ count: Int) -> String {
            L10n.format("auth.sync.ingredients_ok", count)
        }

        static let syncIngredientsFail = LocalizedStringResource(
            "auth.sync.ingredients_fail",
            defaultValue: "食材同步失败"
        )
        static let syncIngredientsEmpty = LocalizedStringResource(
            "auth.sync.ingredients_empty",
            defaultValue: "没有待同步食材"
        )
        static let syncPreferenceOK = LocalizedStringResource(
            "auth.sync.preference_ok",
            defaultValue: "偏好已同步"
        )
        static let syncPreferenceFail = LocalizedStringResource(
            "auth.sync.preference_fail",
            defaultValue: "偏好同步失败"
        )
    }

    // MARK: - Me

    enum Me {
        static let title = LocalizedStringResource("me.title", defaultValue: "我的")
        static let sectionAccount = LocalizedStringResource("me.section.account", defaultValue: "账号")
        static let sectionBehavior = LocalizedStringResource("me.section.behavior", defaultValue: "行为沉淀")
        static let sectionNavigation = LocalizedStringResource("me.section.navigation", defaultValue: "导航偏好")
        static let sectionMore = LocalizedStringResource("me.section.more", defaultValue: "更多")
        static let sectionDebug = LocalizedStringResource("me.section.debug", defaultValue: "联调测试")

        static let loginPromptTitle = LocalizedStringResource(
            "me.login_prompt.title",
            defaultValue: "登录以同步我的数据"
        )
        static let loginPromptSubtitle = LocalizedStringResource(
            "me.login_prompt.subtitle",
            defaultValue: "本地食材、点赞、收藏、历史和导航偏好都会在登录后承接。"
        )
        static let anonymousTitle = LocalizedStringResource(
            "me.anonymous.title",
            defaultValue: "先体验，再决定是否登录"
        )
        static let anonymousSubtitle = LocalizedStringResource(
            "me.anonymous.subtitle",
            defaultValue: "匿名阶段也能录食材、看推荐；登录后再把这些数据同步到账号。"
        )

        static let likes = LocalizedStringResource("me.likes", defaultValue: "点赞")
        static let favorites = LocalizedStringResource("me.favorites", defaultValue: "收藏")
        static let history = LocalizedStringResource("me.history", defaultValue: "历史")
        static let myLikes = LocalizedStringResource("me.my_likes", defaultValue: "我的点赞")
        static let myFavorites = LocalizedStringResource("me.my_favorites", defaultValue: "我的收藏")
        static let recentHistory = LocalizedStringResource("me.recent_history", defaultValue: "最近浏览")
        static let loadingProfile = LocalizedStringResource(
            "me.loading_profile",
            defaultValue: "正在加载我的数据"
        )
        static let emptyTitle = LocalizedStringResource("me.empty.title", defaultValue: "还没有内容")
        static let emptySubtitle = LocalizedStringResource(
            "me.empty.subtitle",
            defaultValue: "继续去看推荐、点收藏或浏览详情，这里就会慢慢沉淀起来。"
        )

        static let preferRecommendFirst = LocalizedStringResource(
            "me.prefer_recommend_first",
            defaultValue: "推荐排在食材前"
        )
        static let tabOrderHint = LocalizedStringResource(
            "me.tab_order_hint",
            defaultValue: "“我的”固定在最右，“开拓”固定在推荐右侧；当前只允许“食材”和“推荐”互换顺序。"
        )
        static let reminders = LocalizedStringResource("me.reminders", defaultValue: "到期提醒")
        static let authStatus = LocalizedStringResource("me.auth_status", defaultValue: "鉴权状态")
        static let authenticated = LocalizedStringResource("me.authenticated", defaultValue: "已登录")
        static let anonymous = LocalizedStringResource("me.anonymous_status", defaultValue: "匿名")
        static let localIngredients = LocalizedStringResource("me.local_ingredients", defaultValue: "本地食材")
        static let apiBaseURL = LocalizedStringResource("me.api_base_url", defaultValue: "接口地址")
        static let debugRunning = LocalizedStringResource(
            "me.debug.running",
            defaultValue: "正在执行联调测试"
        )
        static let debugRecommend = LocalizedStringResource("me.debug.recommend", defaultValue: "测试推荐接口")
        static let debugSearch = LocalizedStringResource("me.debug.search", defaultValue: "测试搜索接口")
        static let debugSession = LocalizedStringResource("me.debug.session", defaultValue: "测试当前登录态")
        static let debugHint = LocalizedStringResource(
            "me.debug.hint",
            defaultValue: "这里专门承接当前阶段的接口联调与状态排查，不再把服务状态常驻放在推荐页。"
        )

        static func pendingSyncCount(_ count: Int) -> String {
            L10n.format("me.pending_sync_count", count)
        }

        static let preferenceSynced = LocalizedStringResource(
            "me.preference_synced",
            defaultValue: "导航偏好已同步"
        )

        static func preferenceSyncFailed(_ detail: String) -> String {
            L10n.format("me.preference_sync_failed", detail)
        }

        static func debugRecommendOK(_ count: Int) -> String {
            L10n.format("me.debug.recommend_ok", count)
        }

        static func debugRecommendFail(_ detail: String) -> String {
            L10n.format("me.debug.recommend_fail", detail)
        }

        static func debugSearchOK(_ count: Int) -> String {
            L10n.format("me.debug.search_ok", count)
        }

        static func debugSearchFail(_ detail: String) -> String {
            L10n.format("me.debug.search_fail", detail)
        }

        static let debugAnonymous = LocalizedStringResource(
            "me.debug.anonymous",
            defaultValue: "当前是匿名状态，推荐、搜索和食材本地流程可以直接体验。"
        )

        static func debugSessionOK(_ email: String) -> String {
            L10n.format("me.debug.session_ok", email)
        }

        static func debugSessionFail(_ detail: String) -> String {
            L10n.format("me.debug.session_fail", detail)
        }
    }

    // MARK: - Settings

    enum Settings {
        static let title = LocalizedStringResource("settings.title", defaultValue: "设置")
        static let general = LocalizedStringResource("settings.section.general", defaultValue: "通用")
        static let reminders = LocalizedStringResource("settings.section.reminders", defaultValue: "提醒")
        static let data = LocalizedStringResource("settings.section.data", defaultValue: "数据")
        static let about = LocalizedStringResource("settings.section.about", defaultValue: "关于")

        static let language = LocalizedStringResource("settings.language", defaultValue: "语言")
        static let languageSystem = LocalizedStringResource("settings.language.system", defaultValue: "跟随系统")
        static let languageChinese = LocalizedStringResource("settings.language.zh_hans", defaultValue: "简体中文")
        static let languageEnglish = LocalizedStringResource("settings.language.en", defaultValue: "English")
        static let languageFooter = LocalizedStringResource(
            "settings.language.footer",
            defaultValue: "切换后立即生效，接口提示也会使用对应语言。"
        )

        static let reminderLead = LocalizedStringResource("settings.reminder.lead", defaultValue: "临期提前")
        static let reminderLeadValue = LocalizedStringResource(
            "settings.reminder.lead_value",
            defaultValue: "2 天（即将支持）"
        )
        static let reminderTime = LocalizedStringResource("settings.reminder.time", defaultValue: "提醒时段")
        static let reminderTimeValue = LocalizedStringResource(
            "settings.reminder.time_value",
            defaultValue: "09:00（即将支持）"
        )

        static let exportBackup = LocalizedStringResource(
            "settings.data.export",
            defaultValue: "导出 / 备份（即将支持）"
        )
        static let importData = LocalizedStringResource(
            "settings.data.import",
            defaultValue: "导入（即将支持）"
        )

        static let version = LocalizedStringResource("settings.about.version", defaultValue: "版本")
        static let entry = LocalizedStringResource("settings.entry", defaultValue: "设置")
    }

    // MARK: - Client errors (non-API)

    enum ClientError {
        static let invalidBaseURL = LocalizedStringResource(
            "client_error.invalid_base_url",
            defaultValue: "API 基础地址无效"
        )
        static let invalidResponse = LocalizedStringResource(
            "client_error.invalid_response",
            defaultValue: "服务端响应格式无效"
        )
        static let unauthorized = LocalizedStringResource(
            "client_error.unauthorized",
            defaultValue: "登录状态已失效，请重新登录"
        )
        static let badRequest = LocalizedStringResource(
            "client_error.bad_request",
            defaultValue: "请求参数有误，请稍后重试"
        )
        static let forbidden = LocalizedStringResource(
            "client_error.forbidden",
            defaultValue: "当前账号没有权限执行这个操作"
        )
        static let notFound = LocalizedStringResource(
            "client_error.not_found",
            defaultValue: "请求的内容不存在"
        )
        static let validation = LocalizedStringResource(
            "client_error.validation",
            defaultValue: "提交的信息有误，请检查后重试"
        )
        static let server = LocalizedStringResource(
            "client_error.server",
            defaultValue: "服务暂时开小差了，请稍后再试"
        )
        static let generic = LocalizedStringResource(
            "client_error.generic",
            defaultValue: "请求失败，请稍后重试"
        )
    }
}
