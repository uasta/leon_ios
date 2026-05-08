import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject private var recommendationStore: RecommendationStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var sessionStore: SessionStore

    let recipe: RecipeSummary

    @State private var detail: RecipeDetail?
    @State private var likedState: Bool
    @State private var favoritedState: Bool
    @State private var isLoading: Bool = false
    @State private var isSubmittingAction: Bool = false
    @State private var errorMessage: String?
    @State private var showActionHint: Bool = false

    private let service = RecommendationService(client: APIClient())
    private let profileService = ProfileService(client: APIClient())

    init(recipe: RecipeSummary) {
        self.recipe = recipe
        _likedState = State(initialValue: recipe.liked)
        _favoritedState = State(initialValue: recipe.favorited)
    }

    var body: some View {
        Group {
            if isLoading && detail == nil {
                ProgressView("正在加载食谱详情")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(effectiveRecipe.title)
                                .font(.title3.weight(.semibold))

                            Text(effectiveRecipe.matchReason ?? "适合当前阶段作为 1.0 的食谱详情承接。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("操作入口") {
                        actionRow(
                            title: "点赞",
                            systemImage: effectiveLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                            tint: .orange
                        ) {
                            await toggleLike()
                        }

                        actionRow(
                            title: "收藏",
                            systemImage: effectiveFavorited ? "bookmark.fill" : "bookmark",
                            tint: .blue
                        ) {
                            await toggleFavorite()
                        }

                        Text(sessionStore.isAuthenticated ? "点赞、收藏和浏览历史会同步沉淀到“我的”。" : "登录后可以把点赞、收藏、历史同步到“我的”。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("食材") {
                        ForEach(detail.ingredients, id: \.self) { item in
                            Text(item)
                        }
                    }

                    Section("步骤") {
                        ForEach(Array(detail.steps.enumerated()), id: \.offset) { index, step in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("步骤 \(index + 1)")
                                    .font(.subheadline.weight(.semibold))
                                Text(step)
                                    .font(.body)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let errorMessage {
                        Section("服务状态") {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("重试") {
                                Task {
                                    await loadDetail()
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    "暂时拿不到详情",
                    systemImage: "fork.knife.circle",
                    description: Text(errorMessage ?? "可以稍后重试，或者先继续浏览推荐列表。")
                )
            }
        }
        .navigationTitle("食谱详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .alert("功能继续联调中", isPresented: $showActionHint) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(sessionStore.isAuthenticated ? "当前请求正在处理中，如果状态没有变化，可以稍后再试一次。" : "先登录账号，再把点赞、收藏和历史同步到“我的”。")
        }
    }

    private func actionRow(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(tint)
                Spacer()
                if isSubmittingAction {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isSubmittingAction)
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchRecipeDetail(id: recipe.id)
            detail = response.data
            likedState = likedState || response.data.liked
            favoritedState = favoritedState || response.data.favorited
        } catch {
            errorMessage = error.localizedDescription
            if detail == nil {
                detail = fallbackDetail
            }
        }

        await recordHistoryIfNeeded()
        isLoading = false
    }

    private func toggleLike() async {
        guard sessionStore.isAuthenticated else {
            showActionHint = true
            return
        }

        isSubmittingAction = true

        do {
            let nextValue = !likedState
            _ = try await profileService.toggleLike(recipe: effectiveRecipe, liked: nextValue)
            self.detail?.liked = nextValue
            likedState = nextValue
            var summary = effectiveRecipe
            summary.liked = nextValue
            profileStore.setRecipeLiked(recipeID: recipe.id, liked: nextValue, fallback: summary)
            recommendationStore.setRecipeLiked(recipeID: recipe.id, liked: nextValue)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmittingAction = false
    }

    private func toggleFavorite() async {
        guard sessionStore.isAuthenticated else {
            showActionHint = true
            return
        }

        isSubmittingAction = true

        do {
            let nextValue = !favoritedState
            _ = try await profileService.toggleFavorite(recipeID: recipe.id, favorited: nextValue)
            self.detail?.favorited = nextValue
            favoritedState = nextValue

            var summary = effectiveRecipe
            summary.favorited = nextValue
            summary.liked = likedState
            profileStore.setRecipeFavorited(recipeID: recipe.id, favorited: nextValue, fallback: summary)
            recommendationStore.setRecipeFavorited(recipeID: recipe.id, favorited: nextValue)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmittingAction = false
    }

    private func recordHistoryIfNeeded() async {
        guard sessionStore.isAuthenticated else { return }

        do {
            _ = try await profileService.recordHistory(recipe: effectiveRecipe)
            profileStore.addToHistory(effectiveRecipe)
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var effectiveRecipe: RecipeSummary {
        var summary = recommendationStore.stateAdjustedRecipe(for: recipe)
        summary.liked = likedState
        summary.favorited = favoritedState
        return summary
    }

    private var effectiveLiked: Bool {
        likedState
    }

    private var effectiveFavorited: Bool {
        favoritedState
    }

    private var fallbackDetail: RecipeDetail {
        RecipeDetail(
            id: recipe.id,
            title: recipe.title,
            coverURL: recipe.coverURL,
            ingredients: ["主食材待补齐", "辅料待补齐", "调味待补齐"],
            steps: [
                "先根据当前推荐结果准备食材。",
                "按家常做法完成预处理与下锅。",
                "等后端详情接口进一步补全更完整的步骤。"
            ],
            liked: recipe.liked,
            favorited: recipe.favorited
        )
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            recipe: RecipeSummary(
                id: 101,
                title: "番茄炒蛋",
                coverURL: nil,
                matchReason: "适合快手开做",
                liked: false,
                favorited: true
            )
        )
        .environmentObject(RecommendationStore())
        .environmentObject(ProfileStore())
        .environmentObject(SessionStore())
    }
}
