import SwiftUI

struct RecommendHomeView: View {
    private enum DiscoverChannel: String, CaseIterable, Identifiable {
        case all = "全部"
        case quick = "快手"
        case home = "家常"
        case stock = "清库存"

        var id: String { rawValue }
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
            .navigationTitle("推荐")
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .searchable(text: $store.query, isPresented: $isSearchPresented, prompt: "搜索菜谱")
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
            sectionHeader("当前食材上下文", actionTitle: "清除") {
                store.clearSelectedIngredientNames()
            }

            Text("已带入 \(store.selectedIngredientNames.count) 个食材：\(store.selectedIngredientNames.joined(separator: "、"))")
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
                    Text("今天吃点什么")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(store.selectedIngredientNames.isEmpty ? "按你当前的收藏偏好、家常灵感和热门菜谱，整理成更适合快速浏览的发现流。" : "已经把你勾选的食材带进来了，先从更接近可开做的方向帮你铺开。")
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
                heroMetricCard(title: "今日推荐", value: "\(store.feed.count)", accent: Color(red: 0.94, green: 0.43, blue: 0.34))
                heroMetricCard(title: "热门词", value: "\(store.hotSearches.count)", accent: Color(red: 0.33, green: 0.62, blue: 0.84))
                heroMetricCard(title: "最近搜索", value: "\(store.searchHistory.count)", accent: Color(red: 0.36, green: 0.66, blue: 0.47))
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
                Text("发现频道")
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
                            Text(channel.rawValue)
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
            sectionHeader(store.selectedIngredientNames.isEmpty ? "发现菜谱" : "按食材推荐")

            if store.isLoading && store.feed.isEmpty {
                ProgressView("正在准备推荐")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if displayedFeed.isEmpty {
                ContentUnavailableView(
                    "还没有推荐结果",
                    systemImage: "fork.knife",
                    description: Text("可以先从食材页带入几个食材，或者直接搜索菜谱。")
                )
            } else {
                waterfallGrid(displayedFeed)
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
                    title: "最近搜索",
                    actionTitle: "清空"
                ) {
                    store.clearSearchHistory()
                } content: {
                    keywordChips(store.searchHistory)
                }
            }

            searchKeywordSection(title: "热门搜索") {
                keywordChips(store.hotSearches)
            }
        }
    }

    private var searchSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("搜索建议", actionTitle: "搜索") {
                Task {
                    await store.searchRecipes()
                }
            }

            Text("输入“\(trimmedQuery)”后，可直接点建议词或继续回车搜索。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.isFetchingSuggestions && store.searchSuggestions.isEmpty {
                ProgressView("正在整理建议")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if store.searchSuggestions.isEmpty {
                ContentUnavailableView(
                    "还没有合适的建议词",
                    systemImage: "text.magnifyingglass",
                    description: Text("可以直接点右上角搜索，也可以换个关键词试试。")
                )
            } else {
                suggestionList(store.searchSuggestions)
            }
        }
    }

    private var committedSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("搜索结果", actionTitle: "重新搜索") {
                Task {
                    await store.retrySearch()
                }
            }

            Text("关键词：\(trimmedQuery)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.isSearching && store.searchResults.isEmpty {
                ProgressView("正在搜索菜谱")
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
                    "没有找到结果",
                    systemImage: "magnifyingglass",
                    description: Text("换个关键词试试，或者先点搜索建议继续找。")
                )
            } else {
                Text("共 \(store.searchResults.count) 条结果")
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
            return "按灵感浏览"
        case .quick:
            return "更适合今天快做"
        case .home:
            return "偏家常稳妥路线"
        case .stock:
            return "优先考虑消耗现有食材"
        }
    }
}

private struct RecipeCard: View {
    let recipe: RecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 14)
                .fill(cardGradient)
                .frame(height: bannerHeight)
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

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                Text(recipe.matchReason ?? "等待真实推荐理由")
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

    private var cardBadgeText: String {
        if recipe.favorited {
            return "已收藏"
        }

        if recipe.liked {
            return "高匹配"
        }

        return "家常推荐"
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
                tags.append("快做")
            }
            if reason.contains("家常") || reason.contains("下饭") {
                tags.append("家常")
            }
            if reason.contains("食材") || reason.contains("匹配") {
                tags.append("食材向")
            }
        }

        if tags.isEmpty {
            tags = ["灵感菜谱", "今晚可做"]
        }

        return Array(tags.prefix(2))
    }

    private var displayLikes: String {
        "\(18 + (recipe.id * 7) % 460)"
    }

    private var displayHeat: String {
        "热度 \(70 + recipe.id % 29)"
    }

    private var authorName: String {
        let names = ["Leon 厨房", "晚餐灵感", "清库存研究所", "今日下饭局"]
        return names[recipe.id % names.count]
    }

    private var authorInitial: String {
        let source = authorName
        return String(source.prefix(1))
    }

    private var channelText: String {
        if recipe.liked {
            return "优先匹配"
        }
        if recipe.favorited {
            return "收藏偏好"
        }
        return "发现流"
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
        .environmentObject(RecommendationStore())
        .environmentObject(SessionStore())
}
