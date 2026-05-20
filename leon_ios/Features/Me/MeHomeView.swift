import SwiftUI

struct MeHomeView: View {
    @EnvironmentObject private var ingredientStore: IngredientStore
    @EnvironmentObject private var recommendationStore: RecommendationStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var preferenceStore: PreferenceStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var showLoginSheet: Bool = false
    @State private var isBootstrappingSession: Bool = false
    @State private var authErrorMessage: String?
    @State private var isLoggingOut: Bool = false
    @State private var debugStatusMessage: String?
    @State private var isRunningDebugCheck: Bool = false

    private let authService = AuthService(client: APIClient())
    private let profileService = ProfileService(client: APIClient())
    private let recommendationService = RecommendationService(client: APIClient())

    var body: some View {
        NavigationStack {
            List {
                accountSection
                behaviorSection
                navigationPreferenceSection
                debugSection
                settingsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .sheet(isPresented: $showLoginSheet) {
                AuthSheetView(initialMode: .login)
            }
            .task {
                await bootstrapAuthenticatedStateIfNeeded()
            }
            .refreshable {
                await refreshProfile()
            }
        }
    }

    private var accountSection: some View {
        Section {
            if sessionStore.isAuthenticated {
                if let user = sessionStore.currentUser {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let syncMessage = profileStore.syncMessage {
                            Text(syncMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }

                    if isLoggingOut {
                        ProgressView("正在退出")
                    } else {
                        Button("退出登录", role: .destructive) {
                            Task {
                                await logout()
                            }
                        }
                    }
                } else if isBootstrappingSession {
                    ProgressView("正在恢复登录状态")
                } else {
                    Text("登录状态已存在，正在准备账号信息。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    showLoginSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("登录以同步我的数据")
                                .font(.headline)
                            Text("本地食材、点赞、收藏、历史和导航偏好都会在这里承接。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("账号")
        }
    }

    private var behaviorSection: some View {
        Section {
            if sessionStore.isAuthenticated {
                if profileStore.isLoading {
                    ProgressView("正在加载我的数据")
                }

                NavigationLink {
                    RecipeCollectionView(title: "我的点赞", recipes: profileStore.likes)
                } label: {
                    LabeledContent("点赞", value: "\(profileStore.likes.count)")
                }

                NavigationLink {
                    RecipeCollectionView(title: "我的收藏", recipes: profileStore.favorites)
                } label: {
                    LabeledContent("收藏", value: "\(profileStore.favorites.count)")
                }

                NavigationLink {
                    RecipeCollectionView(title: "最近浏览", recipes: profileStore.history)
                } label: {
                    LabeledContent("历史", value: "\(profileStore.history.count)")
                }

                if let errorMessage = profileStore.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("先体验，再决定是否登录")
                        .font(.subheadline.weight(.medium))
                    Text("匿名阶段也能录食材、看推荐；登录后再把这些数据同步到账号。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("行为沉淀")
        }
    }

    private var navigationPreferenceSection: some View {
        Section {
            Toggle(
                "推荐排在食材前",
                isOn: Binding(
                    get: { preferenceStore.preferRecommendFirst },
                    set: { newValue in
                        preferenceStore.setPreferRecommendFirst(newValue)
                        Task {
                            await syncPreferencesIfNeeded()
                        }
                    }
                )
            )

            Text("“我的”固定在最右，当前阶段只允许“食材”和“推荐”互换顺序。")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("导航偏好")
        }
    }

    private var settingsSection: some View {
        Section {
            LabeledContent("鉴权状态", value: sessionStore.isAuthenticated ? "已登录" : "匿名")
            LabeledContent("本地食材", value: "\(ingredientStore.activeSyncDrafts().count) 项待同步基底")
            LabeledContent("网络层", value: "APIClient 已接入")
        } header: {
            Text("设置入口")
        }
    }

    private var debugSection: some View {
        Section {
            LabeledContent("接口地址", value: apiBaseURLDisplay)

            if isRunningDebugCheck {
                ProgressView("正在执行联调测试")
            } else {
                Button("测试推荐接口") {
                    Task {
                        await runRecommendationDebugCheck()
                    }
                }

                Button("测试搜索接口") {
                    Task {
                        await runSearchDebugCheck()
                    }
                }

                Button("测试当前登录态") {
                    Task {
                        await runSessionDebugCheck()
                    }
                }
            }

            if let debugStatusMessage {
                Text(debugStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("这里专门承接当前阶段的接口联调与状态排查，不再把服务状态常驻放在推荐页。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("联调测试")
        }
    }

    private func bootstrapAuthenticatedStateIfNeeded() async {
        guard sessionStore.isAuthenticated else {
            profileStore.resetToLocalPreview()
            recommendationStore.clearInteractionState()
            return
        }

        guard sessionStore.currentUser == nil else {
            await profileStore.loadIfNeeded()
            recommendationStore.applyProfileSnapshot(
                likedRecipeIDs: profileStore.likedRecipeIDs,
                favoritedRecipeIDs: profileStore.favoritedRecipeIDs
            )
            return
        }

        isBootstrappingSession = true
        authErrorMessage = nil

        do {
            let userResponse = try await authService.fetchCurrentUser()
            sessionStore.updateCurrentUser(userResponse.data)

            if let preferenceResponse = try? await profileService.fetchPreferences() {
                preferenceStore.applyRemoteTabOrder(preferenceResponse.data.tabOrder)
            }

            await profileStore.loadIfNeeded()
            recommendationStore.applyProfileSnapshot(
                likedRecipeIDs: profileStore.likedRecipeIDs,
                favoritedRecipeIDs: profileStore.favoritedRecipeIDs
            )
        } catch {
            authErrorMessage = error.localizedDescription
            sessionStore.clearSession()
            profileStore.resetToLocalPreview()
            recommendationStore.clearInteractionState()
        }

        isBootstrappingSession = false
    }

    private func refreshProfile() async {
        if sessionStore.isAuthenticated {
            await bootstrapAuthenticatedStateIfNeeded()
            await profileStore.refresh()
            recommendationStore.applyProfileSnapshot(
                likedRecipeIDs: profileStore.likedRecipeIDs,
                favoritedRecipeIDs: profileStore.favoritedRecipeIDs
            )
        } else {
            profileStore.resetToLocalPreview()
            recommendationStore.clearInteractionState()
        }
    }

    private func syncPreferencesIfNeeded() async {
        guard sessionStore.isAuthenticated else { return }

        do {
            let response = try await profileService.updatePreferences(tabOrder: preferenceStore.tabOrder)
            preferenceStore.applyRemoteTabOrder(response.data.tabOrder)
            profileStore.markSyncMessage("导航偏好已同步")
        } catch {
            profileStore.markSyncMessage("导航偏好同步失败：\(error.localizedDescription)")
        }
    }

    private func logout() async {
        isLoggingOut = true
        authErrorMessage = nil

        do {
            _ = try await authService.logout()
            sessionStore.clearSession()
            profileStore.resetToLocalPreview()
            recommendationStore.clearInteractionState()
        } catch {
            authErrorMessage = error.localizedDescription
        }

        isLoggingOut = false
    }

    private func runRecommendationDebugCheck() async {
        isRunningDebugCheck = true
        defer { isRunningDebugCheck = false }

        do {
            let response = try await recommendationService.fetchRecommendationFeed()
            debugStatusMessage = "推荐接口正常，当前返回 \(response.data.count) 条内容。"
        } catch {
            debugStatusMessage = "推荐接口异常：\(error.localizedDescription)"
        }
    }

    private func runSearchDebugCheck() async {
        isRunningDebugCheck = true
        defer { isRunningDebugCheck = false }

        do {
            let response = try await recommendationService.searchRecipes(query: "番茄")
            debugStatusMessage = "搜索接口正常，关键词“番茄”返回 \(response.data.recipes.count) 条结果。"
        } catch {
            debugStatusMessage = "搜索接口异常：\(error.localizedDescription)"
        }
    }

    private func runSessionDebugCheck() async {
        isRunningDebugCheck = true
        defer { isRunningDebugCheck = false }

        if !sessionStore.isAuthenticated {
            debugStatusMessage = "当前是匿名状态，推荐、搜索和食材本地流程可以直接体验。"
            return
        }

        do {
            let response = try await authService.fetchCurrentUser()
            debugStatusMessage = "登录态正常，当前账号：\(response.data.email)。"
        } catch {
            debugStatusMessage = "登录态检查失败：\(error.localizedDescription)"
        }
    }

    private var apiBaseURLDisplay: String {
        (Bundle.main.object(forInfoDictionaryKey: "LEON_API_BASE_URL") as? String) ?? "未配置"
    }
}

private struct RecipeCollectionView: View {
    let title: String
    let recipes: [RecipeSummary]

    var body: some View {
        Group {
            if recipes.isEmpty {
                ContentUnavailableView(
                    "还没有内容",
                    systemImage: "tray",
                    description: Text("继续去看推荐、点收藏或浏览详情，这里就会慢慢沉淀起来。")
                )
            } else {
                List(recipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(recipe.title)
                                    .font(.headline)

                                if recipe.favorited {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }

                                if recipe.liked {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Text(recipe.matchReason ?? "来自账号行为记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MeHomeView()
        .environmentObject(IngredientStore())
        .environmentObject(RecommendationStore())
        .environmentObject(SessionStore())
        .environmentObject(PreferenceStore())
        .environmentObject(ProfileStore())
}
