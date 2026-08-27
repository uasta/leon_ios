import SwiftUI
import UIKit

struct RecommendHomeView: View {
    @EnvironmentObject private var store: RecommendationStore
    @EnvironmentObject private var ingredientStore: IngredientStore

    @State private var isSearchPresented: Bool = false
    @State private var isStockFilterEnabled: Bool = false
    @State private var stockFilterMessage: String?

    private let hotSearchColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 10, alignment: .leading)
    ]

    private var trimmedQuery: String {
        store.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isShowingSearchMode: Bool {
        isSearchPresented || !trimmedQuery.isEmpty || store.hasCommittedSearchForCurrentQuery || store.isSearching
    }

    private var activeIngredientNames: [String] {
        var seen = Set<String>()
        return ingredientStore.items.compactMap { item in
            guard !item.isArchived else { return nil }
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return name
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !store.selectedIngredientNames.isEmpty {
                        contextSection
                    }

                    if isShowingSearchMode {
                        searchSection
                    } else {
                        discoverHeroSection
                        recommendationSection
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.text(L10n.Recommend.homeTitle))
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .searchable(text: $store.query, isPresented: $isSearchPresented, prompt: L10n.text(L10n.Recommend.searchPrompt))
            .onSubmit(of: .search) {
                Task {
                    await store.searchRecipes()
                }
            }
            .onChange(of: store.query) { _, newValue in
                Task {
                    await store.handleSearchQueryChanged(newValue)
                }
            }
            .task {
                await store.loadFeedIfNeeded()
                prefetchCoverImages(for: store.feed)
                await store.loadDailyIfNeeded(ingredientNames: activeIngredientNames)
                await store.loadHotSearchesIfNeeded()
            }
            .onChange(of: store.feed.map(\.id)) { _, _ in
                prefetchCoverImages(for: store.feed)
            }
            .onChange(of: store.selectedIngredientNames) { _, names in
                isStockFilterEnabled = !names.isEmpty
            }
            .refreshable {
                if isShowingSearchMode {
                    if store.hasCommittedSearchForCurrentQuery {
                        await store.retrySearch()
                    } else {
                        await store.loadHotSearchesIfNeeded()
                    }
                } else {
                    await store.retry()
                    await store.refreshDaily(ingredientNames: activeIngredientNames)
                }
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.text(L10n.Recommend.contextTitle), actionTitle: L10n.text(L10n.Action.clear)) {
                isStockFilterEnabled = false
                stockFilterMessage = nil
                store.clearSelectedIngredientNames()
            }

            Text(L10n.Recommend.contextBroughtIn(
                store.selectedIngredientNames.count,
                store.selectedIngredientNames.joined(separator: "、")
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var discoverHeroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text(L10n.Recommend.heroTitle))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(heroSubtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button {
                    isSearchPresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            if store.isLoadingDaily && store.dailyFeatured == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if let featured = store.dailyFeatured {
                NavigationLink(value: featured) {
                    dailyFeaturedCard(featured)
                }
                .buttonStyle(.plain)

                if !store.dailyAlternatives.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(store.dailyAlternatives) { recipe in
                                NavigationLink(value: recipe) {
                                    Text(recipe.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color(red: 0.34, green: 0.21, blue: 0.09))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(Color.white.opacity(0.78), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.hotSearches.prefix(6), id: \.self) { keyword in
                            Button {
                                store.applySearchKeyword(keyword)
                                isSearchPresented = true
                                Task {
                                    await store.searchRecipes()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption)
                                    Text(keyword)
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(Color(red: 0.34, green: 0.21, blue: 0.09))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.78), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(18)
        .background(discoverHeroBackground, in: RoundedRectangle(cornerRadius: 26))
    }

    private var heroSubtitleText: String {
        if !store.preferredFlavors.isEmpty {
            return L10n.Recommend.heroSubtitleFlavors(store.preferredFlavors.joined(separator: "、"))
        }
        if !store.selectedIngredientNames.isEmpty {
            return L10n.text(L10n.Recommend.heroSubtitleWithIngredients)
        }
        return L10n.text(L10n.Recommend.heroSubtitleDefault)
    }

    private func dailyFeaturedCard(_ recipe: RecipeSummary) -> some View {
        HStack(spacing: 12) {
            Group {
                if let coverURL = recipe.coverURL,
                   let url = RecipeImageURLValidator.validImageURL(from: coverURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.white.opacity(0.55)
                        }
                    }
                } else {
                    Color.white.opacity(0.55)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(L10n.Recommend.dailyBadge))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.75, green: 0.36, blue: 0.18))

                Text(recipe.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(recipe.matchReason ?? L10n.text(L10n.Recommend.cardReasonPlaceholder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(store.selectedIngredientNames.isEmpty
                     ? L10n.text(L10n.Recommend.feedTitle)
                     : L10n.text(L10n.Recommend.feedTitleByIngredients))
                    .font(.headline)

                Spacer(minLength: 0)

                stockFilterButton
            }

            if let stockFilterMessage {
                Text(stockFilterMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.isLoading && store.feed.isEmpty {
                ProgressView(L10n.text(L10n.Recommend.feedLoading))
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if store.feed.isEmpty, let errorMessage = store.errorMessage {
                ContentUnavailableView(
                    L10n.text(L10n.Recommend.feedEmptyTitle),
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else if store.feed.isEmpty {
                ContentUnavailableView(
                    L10n.text(L10n.Recommend.feedEmptyTitle),
                    systemImage: "fork.knife",
                    description: Text(L10n.text(L10n.Recommend.feedEmptySubtitle))
                )
            } else {
                waterfallGrid(store.feed)

                if store.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private var stockFilterButton: some View {
        Button {
            toggleStockFilter()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isStockFilterEnabled ? "refrigerator.fill" : "refrigerator")
                Text(L10n.text(L10n.Recommend.filterStock))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isStockFilterEnabled ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isStockFilterEnabled
                    ? AnyShapeStyle(AppTheme.accent)
                    : AnyShapeStyle(Color(.secondarySystemBackground)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleStockFilter() {
        if isStockFilterEnabled {
            isStockFilterEnabled = false
            stockFilterMessage = nil
            store.clearSelectedIngredientNames()
            return
        }

        let names = Array(activeIngredientNames.prefix(20))
        guard !names.isEmpty else {
            stockFilterMessage = L10n.text(L10n.Recommend.filterStockEmpty)
            return
        }

        isStockFilterEnabled = true
        stockFilterMessage = nil
        store.setSelectedIngredientNames(names)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if trimmedQuery.isEmpty {
                searchDiscoverySection
            } else if store.hasCommittedSearchForCurrentQuery {
                committedSearchSection
            } else {
                searchSuggestionSection
            }
        }
    }

    private var searchDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !store.searchHistory.isEmpty {
                searchKeywordSection(
                    title: L10n.text(L10n.Recommend.searchRecent),
                    actionTitle: L10n.text(L10n.Action.clearAll)
                ) {
                    store.clearSearchHistory()
                } content: {
                    keywordChips(store.searchHistory)
                }
            }

            searchKeywordSection(title: L10n.text(L10n.Recommend.searchHot)) {
                keywordChips(store.hotSearches)
            }
        }
    }

    private var searchSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.text(L10n.Recommend.searchSuggestionsTitle), actionTitle: L10n.text(L10n.Action.search)) {
                Task {
                    await store.searchRecipes()
                }
            }

            Text(L10n.Recommend.searchSuggestionsHint(trimmedQuery))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.isFetchingSuggestions && store.searchSuggestions.isEmpty {
                ProgressView(L10n.text(L10n.Recommend.searchSuggestionsLoading))
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if store.searchSuggestions.isEmpty {
                ContentUnavailableView(
                    L10n.text(L10n.Recommend.searchSuggestionsEmptyTitle),
                    systemImage: "text.magnifyingglass",
                    description: Text(L10n.text(L10n.Recommend.searchSuggestionsEmptySubtitle))
                )
            } else {
                suggestionList(store.searchSuggestions)
            }
        }
    }

    private var committedSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.text(L10n.Recommend.searchResultsTitle), actionTitle: L10n.text(L10n.Recommend.searchRetry)) {
                Task {
                    await store.retrySearch()
                }
            }

            Text(L10n.Recommend.searchKeyword(trimmedQuery))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.isSearching && store.searchResults.isEmpty {
                ProgressView(L10n.text(L10n.Recommend.searchLoading))
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if let errorMessage = store.searchErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            } else if store.searchResults.isEmpty {
                ContentUnavailableView(
                    L10n.text(L10n.Recommend.searchEmptyTitle),
                    systemImage: "magnifyingglass",
                    description: Text(L10n.text(L10n.Recommend.searchEmptySubtitle))
                )
            } else {
                Text(L10n.Recommend.searchResultCount(store.searchResults.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                waterfallGrid(store.searchResults)
            }
        }
    }

    private var feedColumnWidth: CGFloat {
        let horizontalPadding: CGFloat = 14 * 2
        let columnSpacing: CGFloat = 12
        return floor((UIScreen.main.bounds.width - horizontalPadding - columnSpacing) / 2)
    }

    private func waterfallGrid(_ recipes: [RecipeSummary]) -> some View {
        let lanes = waterfallColumns(for: recipes)
        let columnWidth = feedColumnWidth

        return HStack(alignment: .top, spacing: 12) {
            ForEach(Array(lanes.enumerated()), id: \.offset) { entry in
                let lane = entry.element
                LazyVStack(spacing: 12) {
                    ForEach(lane) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeCard(recipe: recipe, columnWidth: columnWidth)
                        }
                        .buttonStyle(.plain)
                        .frame(width: columnWidth)
                        .onAppear {
                            Task {
                                await store.loadMoreFeedIfNeeded(currentRecipeID: recipe.id)
                            }
                        }
                    }
                }
                .frame(width: columnWidth, alignment: .top)
            }
        }
    }

    private func waterfallColumns(for recipes: [RecipeSummary]) -> [[RecipeSummary]] {
        var lanes: [[RecipeSummary]] = [[], []]
        var laneHeights: [CGFloat] = [0, 0]

        for recipe in recipes {
            let targetIndex = laneHeights[0] <= laneHeights[1] ? 0 : 1
            lanes[targetIndex].append(recipe)
            laneHeights[targetIndex] += estimatedCardHeight(for: recipe)
        }

        return lanes
    }

    private func estimatedCardHeight(for recipe: RecipeSummary) -> CGFloat {
        let contentWidth = feedColumnWidth - RecipeCard.horizontalPadding * 2
        let imageAspect: CGFloat = {
            if let url = RecipeImageURLValidator.validImageURL(from: recipe.coverURL) {
                return RecipeCoverImageCache.shared.aspect(
                    for: url,
                    fallback: RecipeCoverImageCache.estimatedAspect(forRecipeID: recipe.id)
                )
            }
            return RecipeCoverImageCache.estimatedAspect(forRecipeID: recipe.id)
        }()
        let imageHeight = contentWidth * imageAspect
        let titleHeight: CGFloat = 40
        let reasonHeight: CGFloat = 32
        let footerHeight: CGFloat = 34
        let cardPadding: CGFloat = RecipeCard.horizontalPadding * 2
        let spacing: CGFloat = 16
        return imageHeight + titleHeight + reasonHeight + footerHeight + cardPadding + spacing
    }

    private func prefetchCoverImages(for recipes: [RecipeSummary]) {
        let urls = recipes.compactMap { RecipeImageURLValidator.validImageURL(from: $0.coverURL) }
        RecipeCoverImageCache.shared.prefetch(
            urls: urls,
            minAspect: RecipeCard.minImageAspect,
            maxAspect: RecipeCard.maxImageAspect
        )
    }

    private func keywordChips(_ keywords: [String]) -> some View {
        LazyVGrid(columns: hotSearchColumns, alignment: .leading, spacing: 10) {
            ForEach(keywords, id: \.self) { keyword in
                Button(keyword) {
                    store.applySearchKeyword(keyword)
                    Task {
                        await store.searchRecipes()
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }
        }
    }

    private func suggestionList(_ suggestions: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    store.applySearchKeyword(suggestion)
                    Task {
                        await store.searchRecipes()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(suggestion)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func searchKeywordSection<Content: View>(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title, actionTitle: actionTitle, action: action)
            content()
        }
    }

    private func sectionHeader(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption)
            }
        }
    }

    private func heroMetricCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 32, height: 32)
                .padding(10)
        }
    }

    private var discoverHeroBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.93, blue: 0.84),
                Color(red: 0.95, green: 0.83, blue: 0.72),
                Color(red: 0.91, green: 0.95, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct RecipeCard: View {
    let recipe: RecipeSummary
    let columnWidth: CGFloat

    static let horizontalPadding: CGFloat = 10
    /// 高度下限 / 上限相对宽度的比例，避免极端横图过矮、竖图过长。
    static let minImageAspect: CGFloat = 0.72
    static let maxImageAspect: CGFloat = 1.75

    private var contentWidth: CGFloat {
        max(columnWidth - Self.horizontalPadding * 2, 0)
    }

    private var estimatedImageAspect: CGFloat {
        if let url = RecipeImageURLValidator.validImageURL(from: recipe.coverURL) {
            return RecipeCoverImageCache.shared.aspect(
                for: url,
                fallback: RecipeCoverImageCache.estimatedAspect(forRecipeID: recipe.id)
            )
        }
        return RecipeCoverImageCache.estimatedAspect(forRecipeID: recipe.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bannerView

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(displayMatchReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(avatarGradient)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Text(authorInitial)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authorName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(channelText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Label(displayLikes, systemImage: recipe.favorited ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(recipe.favorited ? Color.red : .secondary)
            }
        }
        .padding(Self.horizontalPadding)
        .frame(width: columnWidth, alignment: .topLeading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var displayMatchReason: String {
        let fallback = L10n.text(L10n.Recommend.cardReasonPlaceholder)
        guard let reason = recipe.matchReason?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reason.isEmpty else {
            return fallback
        }

        if reason.contains("://") || reason.lowercased().contains(".html") {
            return fallback
        }

        return reason
    }

    private var bannerView: some View {
        ZStack(alignment: .bottomLeading) {
            bannerImageFill

            LinearGradient(
                colors: [.clear, .black.opacity(0.28)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(cardBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.22), in: Capsule())

                if let primaryTag = cardTags.first {
                    Text(primaryTag)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(10)
        }
        .frame(width: contentWidth)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Text(displayHeat)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.22), in: Capsule())
                .padding(10)
        }
    }

    @ViewBuilder
    private var bannerImageFill: some View {
        if let url = RecipeImageURLValidator.validImageURL(from: recipe.coverURL) {
            AdaptiveCoverImage(
                url: url,
                width: contentWidth,
                minAspect: Self.minImageAspect,
                maxAspect: Self.maxImageAspect,
                placeholderAspect: estimatedImageAspect,
                placeholder: { aspect in
                    Rectangle()
                        .fill(cardGradient)
                        .frame(width: contentWidth, height: contentWidth * aspect)
                }
            )
        } else {
            Rectangle()
                .fill(cardGradient)
                .frame(width: contentWidth, height: contentWidth * estimatedImageAspect)
        }
    }

    private var cardBadgeText: String {
        if recipe.favorited {
            return L10n.text(L10n.Recommend.cardBadgeFavorited)
        }

        if recipe.liked {
            return L10n.text(L10n.Recommend.cardBadgeHighMatch)
        }

        return L10n.text(L10n.Recommend.cardBadgeHome)
    }

    private var cardGradient: LinearGradient {
        if recipe.favorited {
            return LinearGradient(colors: [Color(red: 0.22, green: 0.48, blue: 0.78), Color(red: 0.38, green: 0.73, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        if recipe.liked {
            return LinearGradient(colors: [Color(red: 0.85, green: 0.46, blue: 0.21), Color(red: 0.96, green: 0.72, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        return LinearGradient(colors: [Color(red: 0.23, green: 0.62, blue: 0.47), Color(red: 0.74, green: 0.83, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var cardTags: [String] {
        var tags: [String] = []

        if let reason = recipe.matchReason {
            if reason.contains("快手") || reason.contains("10") || reason.contains("15") {
                tags.append(L10n.text(L10n.Recommend.cardTagQuick))
            }
            if reason.contains("家常") || reason.contains("下饭") {
                tags.append(L10n.text(L10n.Recommend.cardTagHome))
            }
            if reason.contains("食材") || reason.contains("匹配") {
                tags.append(L10n.text(L10n.Recommend.cardTagIngredient))
            }
        }

        if tags.isEmpty {
            tags = [
                L10n.text(L10n.Recommend.cardTagInspiration),
                L10n.text(L10n.Recommend.cardTagTonight)
            ]
        }

        return Array(tags.prefix(2))
    }

    private var displayLikes: String {
        "\(18 + (recipe.id * 7) % 460)"
    }

    private var displayHeat: String {
        L10n.Recommend.cardHeat(recipe.heat ?? 0)
    }

    private var authorName: String {
        let names = [
            L10n.text(L10n.Recommend.authorKitchen),
            L10n.text(L10n.Recommend.authorDinner),
            L10n.text(L10n.Recommend.authorStock),
            L10n.text(L10n.Recommend.authorToday)
        ]
        return names[recipe.id % names.count]
    }

    private var authorInitial: String {
        String(authorName.prefix(1))
    }

    private var channelText: String {
        if recipe.liked {
            return L10n.text(L10n.Recommend.cardChannelPriority)
        }
        if recipe.favorited {
            return L10n.text(L10n.Recommend.cardChannelFavorite)
        }
        return L10n.text(L10n.Recommend.cardChannelDiscover)
    }

    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.53, blue: 0.36),
                Color(red: 0.84, green: 0.34, blue: 0.33)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// 固定宽度；高度在首帧锁定（缓存比例优先，否则用预估），加载完成后只淡入图片，不再改高度。
private struct AdaptiveCoverImage<Placeholder: View>: View {
    let url: URL
    let width: CGFloat
    let minAspect: CGFloat
    let maxAspect: CGFloat
    let placeholderAspect: CGFloat
    @ViewBuilder let placeholder: (_ aspect: CGFloat) -> Placeholder

    @State private var image: UIImage?
    @State private var aspect: CGFloat
    @State private var imageOpacity: Double
    @State private var loadFailed = false

    init(
        url: URL,
        width: CGFloat,
        minAspect: CGFloat,
        maxAspect: CGFloat,
        placeholderAspect: CGFloat,
        @ViewBuilder placeholder: @escaping (_ aspect: CGFloat) -> Placeholder
    ) {
        self.url = url
        self.width = width
        self.minAspect = minAspect
        self.maxAspect = maxAspect
        self.placeholderAspect = placeholderAspect
        self.placeholder = placeholder

        if let cached = RecipeCoverImageCache.shared.entry(for: url) {
            _image = State(initialValue: cached.image)
            _aspect = State(initialValue: cached.aspect)
            _imageOpacity = State(initialValue: 1)
        } else {
            _image = State(initialValue: nil)
            _aspect = State(initialValue: placeholderAspect)
            _imageOpacity = State(initialValue: 0)
        }
    }

    private var displayHeight: CGFloat {
        width * aspect
    }

    var body: some View {
        ZStack {
            placeholder(aspect)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: displayHeight)
                    .clipped()
                    .opacity(imageOpacity)
            } else if !loadFailed {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: width, height: displayHeight)
        .task(id: url.absoluteString) {
            await loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() async {
        if image != nil {
            return
        }

        guard let entry = await RecipeCoverImageCache.shared.image(
            for: url,
            minAspect: minAspect,
            maxAspect: maxAspect
        ) else {
            loadFailed = true
            return
        }

        // 高度已在首帧锁定，这里只淡入图片，避免文案出来后整卡闪动。
        image = entry.image
        withAnimation(.easeInOut(duration: 0.22)) {
            imageOpacity = 1
        }
    }
}

#Preview {
    RecommendHomeView()
        .environmentObject(RecommendationStore(feed: RecommendationStore.sampleFeed))
        .environmentObject(IngredientStore())
        .environmentObject(SessionStore())
}
