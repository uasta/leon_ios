import SwiftUI

struct RecommendHomeView: View {
    private enum DiscoverChannel: String, CaseIterable, Identifiable {
        case all
        case quick
        case home
        case stock

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return L10n.text(L10n.Recommend.channelAll)
            case .quick: return L10n.text(L10n.Recommend.channelQuick)
            case .home: return L10n.text(L10n.Recommend.channelHome)
            case .stock: return L10n.text(L10n.Recommend.channelStock)
            }
        }
    }

    @EnvironmentObject private var store: RecommendationStore

    @State private var isSearchPresented: Bool = false
    @State private var selectedChannel: DiscoverChannel = .all

    private let hotSearchColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 10, alignment: .leading)
    ]

    private var trimmedQuery: String {
        store.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isShowingSearchMode: Bool {
        isSearchPresented || !trimmedQuery.isEmpty || store.hasCommittedSearchForCurrentQuery || store.isSearching
    }

    private var displayedFeed: [RecipeSummary] {
        switch selectedChannel {
        case .all:
            return store.feed
        case .quick:
            return filteredFeed(matching: ["快手", "10 分钟", "15 分钟", "简单"])
        case .home:
            return filteredFeed(matching: ["家常", "下饭", "番茄", "土豆"])
        case .stock:
            return filteredFeed(matching: ["清库存", "食材", "适合", "主食材"])
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
                        discoverChannelSection
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
            .refreshable {
                if isShowingSearchMode {
                    if store.hasCommittedSearchForCurrentQuery {
                        await store.retrySearch()
                    } else {
                        await store.loadHotSearchesIfNeeded()
                    }
                } else {
                    await store.retry()
                }
            }
            .task {
                await store.loadFeedIfNeeded()
                await store.loadHotSearchesIfNeeded()
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.text(L10n.Recommend.contextTitle), actionTitle: L10n.text(L10n.Action.clear)) {
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
                    Text(store.selectedIngredientNames.isEmpty
                         ? L10n.text(L10n.Recommend.heroSubtitleDefault)
                         : L10n.text(L10n.Recommend.heroSubtitleWithIngredients))
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

            HStack(spacing: 10) {
                heroMetricCard(title: L10n.text(L10n.Recommend.heroMetricToday), value: "\(store.feed.count)", accent: Color(red: 0.94, green: 0.43, blue: 0.34))
                heroMetricCard(title: L10n.text(L10n.Recommend.heroMetricHot), value: "\(store.hotSearches.count)", accent: Color(red: 0.33, green: 0.62, blue: 0.84))
                heroMetricCard(title: L10n.text(L10n.Recommend.heroMetricRecent), value: "\(store.searchHistory.count)", accent: Color(red: 0.36, green: 0.66, blue: 0.47))
            }

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
        .padding(18)
        .background(discoverHeroBackground, in: RoundedRectangle(cornerRadius: 26))
    }

    private var discoverChannelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.text(L10n.Recommend.channelSection))
                    .font(.headline)
                Spacer()
                Text(channelSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DiscoverChannel.allCases) { channel in
                        Button {
                            selectedChannel = channel
                        } label: {
                            Text(channel.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedChannel == channel ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    selectedChannel == channel
                                        ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.94, green: 0.42, blue: 0.35), Color(red: 0.96, green: 0.61, blue: 0.31)], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color(.secondarySystemBackground)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(store.selectedIngredientNames.isEmpty
                          ? L10n.text(L10n.Recommend.feedTitle)
                          : L10n.text(L10n.Recommend.feedTitleByIngredients))

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
            } else if displayedFeed.isEmpty {
                ContentUnavailableView(
                    L10n.text(L10n.Recommend.feedEmptyTitle),
                    systemImage: "fork.knife",
                    description: Text(L10n.text(L10n.Recommend.feedEmptySubtitle))
                )
            } else {
                waterfallGrid(displayedFeed)

                if store.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
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

    private func waterfallGrid(_ recipes: [RecipeSummary]) -> some View {
        let lanes = waterfallColumns(for: recipes)

        return HStack(alignment: .top, spacing: 12) {
            ForEach(Array(lanes.enumerated()), id: \.offset) { entry in
                let lane = entry.element
                LazyVStack(spacing: 12) {
                    ForEach(lane) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeCard(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task {
                                await store.loadMoreFeedIfNeeded(currentRecipeID: recipe.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
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
        let titleWeight = CGFloat(max(recipe.title.count, 12)) * 1.7
        let reasonWeight = CGFloat(max(recipe.matchReason?.count ?? 26, 22)) * 1.0
        let bannerBase = CGFloat(132 + (recipe.id % 3) * 28)
        return bannerBase + titleWeight + reasonWeight + 96
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

    private func filteredFeed(matching keywords: [String]) -> [RecipeSummary] {
        let filtered = store.feed.filter { recipe in
            let source = [recipe.title, recipe.matchReason ?? ""].joined(separator: " ")
            return keywords.contains { source.localizedCaseInsensitiveContains($0) }
        }

        return filtered.isEmpty ? store.feed : filtered
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

    private var channelSubtitle: String {
        switch selectedChannel {
        case .all:
            return L10n.text(L10n.Recommend.channelSubtitleAll)
        case .quick:
            return L10n.text(L10n.Recommend.channelSubtitleQuick)
        case .home:
            return L10n.text(L10n.Recommend.channelSubtitleHome)
        case .stock:
            return L10n.text(L10n.Recommend.channelSubtitleStock)
        }
    }
}

private struct RecipeCard: View {
    let recipe: RecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bannerView
                .frame(height: bannerHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                Text(recipe.matchReason ?? L10n.text(L10n.Recommend.cardReasonPlaceholder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
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

                Spacer()

                Label(displayLikes, systemImage: recipe.favorited ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(recipe.favorited ? Color.red : .secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var bannerView: some View {
        ZStack {
            if let coverURL = recipe.coverURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        cardGradientFill
                    default:
                        cardGradientFill
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    }
                }
            } else {
                cardGradientFill
            }
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(cardBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.18), in: Capsule())

                HStack(spacing: 8) {
                    ForEach(cardTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                }
            }
            .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 6) {
                Image(systemName: recipe.favorited ? "bookmark.fill" : "sparkles")
                    .font(.caption.weight(.semibold))
                Text(displayHeat)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(10)
        }
    }

    private var cardGradientFill: some View {
        Rectangle()
            .fill(cardGradient)
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

    private var bannerHeight: CGFloat {
        CGFloat(132 + (recipe.id % 3) * 28)
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
        L10n.Recommend.cardHeat(70 + recipe.id % 29)
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
        let source = authorName
        return String(source.prefix(1))
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

#Preview {
    RecommendHomeView()
        .environmentObject(RecommendationStore(feed: RecommendationStore.sampleFeed))
        .environmentObject(SessionStore())
}
