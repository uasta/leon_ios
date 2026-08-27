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
    @State private var galleryPresented: Bool = false
    @State private var galleryIndex: Int = 0

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
                    if let coverURL = detail.coverURL,
                       let url = RecipeImageURLValidator.validImageURL(from: coverURL) {
                        Section {
                            Button {
                                openGallery(at: indexOfImageURL(url))
                            } label: {
                                recipeRemoteImage(url: url)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(effectiveRecipe.title)
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 16) {
                                    Button {
                                        Task { await toggleFavorite() }
                                    } label: {
                                        Image(systemName: effectiveFavorited ? "bookmark.fill" : "bookmark")
                                            .font(.title3)
                                            .foregroundStyle(effectiveFavorited ? AppTheme.accent : .primary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSubmittingAction)
                                    .accessibilityLabel(L10n.text(L10n.Recommend.detailFavorite))

                                    Button {
                                        Task { await toggleLike() }
                                    } label: {
                                        Image(systemName: effectiveLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                            .font(.title3)
                                            .foregroundStyle(effectiveLiked ? .orange : .primary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSubmittingAction)
                                    .accessibilityLabel(L10n.text(L10n.Recommend.detailLike))
                                }
                            }

                            if let reason = displayMatchReason {
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L10n.text(L10n.Recommend.detailIngredients))
                                    .font(.headline)
                                Spacer(minLength: 0)
                                Text(L10n.Recommend.detailIngredientsCount(detail.ingredients.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            IngredientTagFlow(items: detail.ingredients)
                        }
                        .padding(.vertical, 2)
                    }

                    Section(L10n.text(L10n.Recommend.detailSteps)) {
                        ForEach(detail.steps) { step in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.Recommend.detailStep(step.index > 0 ? step.index : 1))
                                    .font(.subheadline.weight(.semibold))

                                if let imageURL = step.imageURL,
                                   let url = RecipeImageURLValidator.validImageURL(from: imageURL) {
                                    Button {
                                        openGallery(at: indexOfImageURL(url))
                                    } label: {
                                        recipeRemoteImage(url: url)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text(step.text)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 2)
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
        .fullScreenCover(isPresented: $galleryPresented) {
            RecipeImageGalleryView(
                imageURLs: galleryImageURLs,
                selectedIndex: $galleryIndex
            )
        }
    }

    private var displayMatchReason: String? {
        guard let reason = effectiveRecipe.matchReason?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !reason.isEmpty else {
            return nil
        }

        if reason.contains("评分") || reason.contains("默认推荐流") || reason.contains("推荐骨架") {
            return nil
        }

        return reason
    }

    @ViewBuilder
    private func recipeRemoteImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            default:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .clipped()
    }

    private var galleryImageURLs: [URL] {
        guard let detail else { return [] }

        var urls: [URL] = []
        if let coverURL = detail.coverURL,
           let url = RecipeImageURLValidator.validImageURL(from: coverURL) {
            urls.append(url)
        }

        for step in detail.steps {
            guard let imageURL = step.imageURL,
                  let url = RecipeImageURLValidator.validImageURL(from: imageURL),
                  !urls.contains(url) else { continue }
            urls.append(url)
        }

        return urls
    }

    private func openGallery(at index: Int) {
        guard !galleryImageURLs.isEmpty else { return }
        galleryIndex = min(max(index, 0), galleryImageURLs.count - 1)
        galleryPresented = true
    }

    private func indexOfImageURL(_ url: URL) -> Int {
        galleryImageURLs.firstIndex(of: url) ?? 0
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

private struct IngredientTagFlow: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            recipe: RecipeSummary(
                id: 101,
                title: "番茄炒蛋",
                coverURL: nil,
                matchReason: "十分钟 · 简单",
                heat: 36,
                liked: false,
                favorited: true
            )
        )
        .environmentObject(RecommendationStore())
        .environmentObject(ProfileStore())
        .environmentObject(SessionStore())
    }
}
