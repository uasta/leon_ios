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
                settingsSection
                #if DEBUG
                debugSection
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle(L10n.Me.title)
            .sheet(isPresented: $showLoginSheet) {
                AuthSheetView(initialMode: .login)
                    .environmentObject(ingredientStore)
                    .environmentObject(recommendationStore)
                    .environmentObject(sessionStore)
                    .environmentObject(preferenceStore)
                    .environmentObject(profileStore)
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
                        ProgressView(L10n.Auth.loggingOut)
                    } else {
                        Button(L10n.Auth.logout, role: .destructive) {
                            Task {
                                await logout()
                            }
                        }
                    }
                } else if isBootstrappingSession {
                    ProgressView(L10n.Auth.restoringSession)
                } else {
                    Text(L10n.Auth.preparingAccount)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentSoft)
                                .frame(width: 44, height: 44)

                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Me.loginPromptTitle)
                                .font(.headline)
                            Text(L10n.Me.loginPromptSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button {
                        showLoginSheet = true
                    } label: {
                        Text(L10n.Auth.loginRegister)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.accent, Color(red: 0.28, green: 0.52, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            if let authErrorMessage {
                Text(authErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.Me.sectionAccount)
        }
    }

    private var behaviorSection: some View {
        Section {
            if sessionStore.isAuthenticated {
                if profileStore.isLoading {
                    ProgressView(L10n.Me.loadingProfile)
                }

                NavigationLink {
                    RecipeCollectionView(title: L10n.text(L10n.Me.myLikes), recipes: profileStore.likes)
                } label: {
                    LabeledContent(L10n.Me.likes, value: "\(profileStore.likes.count)")
                }

                NavigationLink {
                    RecipeCollectionView(title: L10n.text(L10n.Me.myFavorites), recipes: profileStore.favorites)
                } label: {
                    LabeledContent(L10n.Me.favorites, value: "\(profileStore.favorites.count)")
                }

                NavigationLink {
                    RecipeCollectionView(title: L10n.text(L10n.Me.recentHistory), recipes: profileStore.history)
                } label: {
                    LabeledContent(L10n.Me.history, value: "\(profileStore.history.count)")
                }

                if let errorMessage = profileStore.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.Me.anonymousTitle)
                        .font(.subheadline.weight(.medium))
                    Text(L10n.Me.anonymousSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L10n.Me.sectionBehavior)
        }
    }

    private var navigationPreferenceSection: some View {
        Section {
            Toggle(
                L10n.Me.preferRecommendFirst,
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

            Text(L10n.Me.tabOrderHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text(L10n.Me.sectionNavigation)
        }
    }

    private var settingsSection: some View {
        Section {
            NavigationLink {
                SettingsView()
            } label: {
                Label(L10n.Settings.entry, systemImage: "gearshape")
            }

            NavigationLink {
                RemindersView()
            } label: {
                Label(L10n.Me.reminders, systemImage: "bell.badge")
            }

            LabeledContent(
                L10n.Me.authStatus,
                value: sessionStore.isAuthenticated
                    ? L10n.text(L10n.Me.authenticated)
                    : L10n.text(L10n.Me.anonymous)
            )
            LabeledContent(
                L10n.Me.localIngredients,
                value: L10n.Me.pendingSyncCount(ingredientStore.activeSyncDrafts().count)
            )
        } header: {
            Text(L10n.Me.sectionMore)
        }
    }

    private var debugSection: some View {
        Section {
            LabeledContent(L10n.Me.apiBaseURL, value: apiBaseURLDisplay)

            if isRunningDebugCheck {
                ProgressView(L10n.Me.debugRunning)
            } else {
                Button(L10n.Me.debugRecommend) {
                    Task {
                        await runRecommendationDebugCheck()
                    }
                }

                Button(L10n.Me.debugSearch) {
                    Task {
                        await runSearchDebugCheck()
                    }
                }

                Button(L10n.Me.debugSession) {
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
                Text(L10n.Me.debugHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(L10n.Me.sectionDebug)
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
            let response = try await profileService.updatePreferences(tabOrder: preferenceStore.syncableTabOrder)
            preferenceStore.applyRemoteTabOrder(response.data.tabOrder)
            profileStore.markSyncMessage(L10n.text(L10n.Me.preferenceSynced))
        } catch {
            profileStore.markSyncMessage(L10n.Me.preferenceSyncFailed(error.localizedDescription))
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
            debugStatusMessage = L10n.Me.debugRecommendOK(response.data.items.count)
        } catch {
            debugStatusMessage = L10n.Me.debugRecommendFail(error.localizedDescription)
        }
    }

    private func runSearchDebugCheck() async {
        isRunningDebugCheck = true
        defer { isRunningDebugCheck = false }

        do {
            let response = try await recommendationService.searchRecipes(query: "番茄")
            debugStatusMessage = L10n.Me.debugSearchOK(response.data.recipes.count)
        } catch {
            debugStatusMessage = L10n.Me.debugSearchFail(error.localizedDescription)
        }
    }

    private func runSessionDebugCheck() async {
        isRunningDebugCheck = true
        defer { isRunningDebugCheck = false }

        if !sessionStore.isAuthenticated {
            debugStatusMessage = L10n.text(L10n.Me.debugAnonymous)
            return
        }

        do {
            let response = try await authService.fetchCurrentUser()
            debugStatusMessage = L10n.Me.debugSessionOK(response.data.email)
        } catch {
            debugStatusMessage = L10n.Me.debugSessionFail(error.localizedDescription)
        }
    }

    private var apiBaseURLDisplay: String {
        (Bundle.main.object(forInfoDictionaryKey: "LEON_API_BASE_URL") as? String)
            ?? L10n.text(L10n.Common.notConfigured)
    }
}

private struct RecipeCollectionView: View {
    let title: String
    let recipes: [RecipeSummary]

    var body: some View {
        Group {
            if recipes.isEmpty {
                ContentUnavailableView(
                    L10n.Me.emptyTitle,
                    systemImage: "tray",
                    description: Text(L10n.Me.emptySubtitle)
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

                            Text(recipe.matchReason ?? L10n.text(L10n.Common.fromAccountBehavior))
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
