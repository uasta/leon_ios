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

    private let authService = AuthService(client: APIClient())
    private let profileService = ProfileService(client: APIClient())

    var body: some View {
        NavigationStack {
            List {
                accountSection
                behaviorSection
                navigationPreferenceSection
                settingsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .sheet(isPresented: $showLoginSheet) {
                LoginSheetView()
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
}

private struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ingredientStore: IngredientStore
    @EnvironmentObject private var recommendationStore: RecommendationStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var preferenceStore: PreferenceStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private let authService = AuthService(client: APIClient())
    private let ingredientService = IngredientService(client: APIClient())
    private let profileService = ProfileService(client: APIClient())

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)

                    SecureField("密码", text: $password)
                } header: {
                    Text("开发环境登录")
                } footer: {
                    Text("当前后端先走邮箱账号体系。登录后会自动同步本地食材和导航偏好。")
                }

                Section {
                    Label("同步本地食材到账号", systemImage: "arrow.triangle.2.circlepath")
                    Label("同步当前 Tab 顺序偏好", systemImage: "square.grid.3x1.folder.badge.plus")
                    Label("拉取我的点赞、收藏和历史", systemImage: "tray.full")
                } header: {
                    Text("登录后会发生什么")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("状态")
                    }
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("登录") {
                            Task {
                                await submit()
                            }
                        }
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        do {
            let loginResponse = try await authService.login(email: email, password: password)
            let loginData = loginResponse.data
            sessionStore.configureAuthenticatedSession(user: loginData.user, token: loginData.token)

            var syncNotes: [String] = []
            let drafts = ingredientStore.activeSyncDrafts()
            if !drafts.isEmpty {
                do {
                    let syncResponse = try await ingredientService.bootstrapLocalIngredients(drafts)
                    syncNotes.append(
                        "食材同步 \(syncResponse.data.syncedCount) 项"
                    )
                } catch {
                    syncNotes.append("食材同步失败")
                }
            } else {
                syncNotes.append("没有待同步食材")
            }

            do {
                let preferenceResponse = try await profileService.updatePreferences(tabOrder: preferenceStore.tabOrder)
                preferenceStore.applyRemoteTabOrder(preferenceResponse.data.tabOrder)
                syncNotes.append("偏好已同步")
            } catch {
                syncNotes.append("偏好同步失败")
            }

            await profileStore.refresh()
            recommendationStore.applyProfileSnapshot(
                likedRecipeIDs: profileStore.likedRecipeIDs,
                favoritedRecipeIDs: profileStore.favoritedRecipeIDs
            )
            profileStore.markSyncMessage(syncNotes.joined(separator: "，"))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
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
                    NavigationLink(value: recipe) {
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
                .navigationDestination(for: RecipeSummary.self) { recipe in
                    RecipeDetailView(recipe: recipe)
                }
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
