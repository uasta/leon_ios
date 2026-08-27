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
    @State private var showAuthSheet: Bool = false

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
                ProgressView(L10n.text(L10n.Recommend.detailLoading))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                List {
                    if let coverURL = detail.coverURL, let url = URL(string: coverURL) {
                        Section {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                        .overlay {
                                            ProgressView()
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(effectiveRecipe.title)
                                .font(.title3.weight(.semibold))

                            Text(effectiveRecipe.matchReason ?? L10n.text(L10n.Recommend.detailReasonFallback))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section(L10n.text(L10n.Recommend.detailActionsSection)) {
                        actionRow(
                            title: L10n.text(L10n.Recommend.detailLike),
                            systemImage: effectiveLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                            tint: .orange
                        ) {
                            await toggleLike()
                        }

                        actionRow(
                            title: L10n.text(L10n.Recommend.detailFavorite),
                            systemImage: effectiveFavorited ? "bookmark.fill" : "bookmark",
                            tint: .blue
                        ) {
                            await toggleFavorite()
                        }

                        Text(sessionStore.isAuthenticated
                             ? L10n.text(L10n.Recommend.detailSyncHintAuthed)
                             : L10n.text(L10n.Recommend.detailSyncHintGuest))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section(L10n.text(L10n.Recommend.detailIngredients)) {
                        ForEach(detail.ingredients, id: \.self) { item in
                            Text(item)
                        }
                    }

                    Section(L10n.text(L10n.Recommend.detailSteps)) {
                        ForEach(detail.steps) { step in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Recommend.detailStep(step.index > 0 ? step.index : 1))
                                    .font(.subheadline.weight(.semibold))

                                if let imageURL = step.imageURL, let url = URL(string: imageURL) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Text(step.text)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if let errorMessage {
                        Section(L10n.text(L10n.Recommend.detailServiceStatus)) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button(L10n.text(L10n.Common.retry)) {
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
                    L10n.text(L10n.Recommend.detailUnavailableTitle),
                    systemImage: "fork.knife.circle",
                    description: Text(errorMessage ?? L10n.text(L10n.Recommend.detailUnavailableSubtitle))
                )
            }
        }
        .navigationTitle(L10n.text(L10n.Recommend.detailTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthSheetView(initialMode: .login)
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
            showAuthSheet = true
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
            showAuthSheet = true
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
            ingredients: [
                L10n.text(L10n.Recommend.fallbackIngredientMain),
                L10n.text(L10n.Recommend.fallbackIngredientSide),
                L10n.text(L10n.Recommend.fallbackIngredientSeasoning)
            ],
            steps: [
                RecipeStep(index: 1, text: L10n.text(L10n.Recommend.fallbackStep1)),
                RecipeStep(index: 2, text: L10n.text(L10n.Recommend.fallbackStep2)),
                RecipeStep(index: 3, text: L10n.text(L10n.Recommend.fallbackStep3)),
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
