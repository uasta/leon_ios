import Foundation
import Combine

@MainActor
final class RecommendationStore: ObservableObject {
    private struct InteractionState {
        var liked: Bool?
        var favorited: Bool?
    }

    private static let searchHistoryKey = "recommend.searchHistory"
    private static let maxSearchHistoryCount = 8

    @Published var query: String = ""
    @Published private(set) var feed: [RecipeSummary]
    @Published private(set) var searchResults: [RecipeSummary]
    @Published private(set) var searchSuggestions: [String]
    @Published private(set) var searchHistory: [String]
    @Published private(set) var hotSearches: [String]
    @Published private(set) var selectedIngredientNames: [String]
    @Published private(set) var dailyItems: [RecipeSummary]
    @Published private(set) var dailyFeatured: RecipeSummary?
    @Published private(set) var dailyAlternatives: [RecipeSummary]
    @Published private(set) var dailyBatch: Int
    @Published private(set) var preferredFlavors: [String]
    @Published private(set) var isLoadingDaily: Bool
    @Published private(set) var isLoading: Bool
    @Published private(set) var isLoadingMore: Bool
    @Published private(set) var hasMoreFeed: Bool
    @Published private(set) var feedSeed: Int
    @Published private(set) var isSearching: Bool
    @Published private(set) var isFetchingSuggestions: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var searchErrorMessage: String?
    @Published private(set) var lastSubmittedQuery: String?

    private let service: RecommendationService
    private var rawFeed: [RecipeSummary]
    private var rawSearchResults: [RecipeSummary]
    private var feedPage: Int = 0
    private var hasLoadedFeed = false
    private var hasLoadedHotSearches = false
    private var hasLoadedDaily = false
    private var interactionOverrides: [Int: InteractionState] = [:]
    private var latestSuggestionQuery: String?

    init(
        service: RecommendationService = RecommendationService(client: APIClient()),
        feed: [RecipeSummary] = [],
        searchResults: [RecipeSummary] = [],
        searchSuggestions: [String] = [],
        hotSearches: [String] = RecommendationStore.sampleHotSearches,
        selectedIngredientNames: [String] = [],
        isLoading: Bool = false,
        isSearching: Bool = false,
        errorMessage: String? = nil
    ) {
        self.service = service
        self.rawFeed = feed
        self.rawSearchResults = searchResults
        self.feed = feed
        self.searchResults = searchResults
        self.searchSuggestions = searchSuggestions
        self.searchHistory = Self.loadSearchHistory()
        self.hotSearches = hotSearches
        self.selectedIngredientNames = Self.normalizedNames(from: selectedIngredientNames)
        self.dailyItems = []
        self.dailyFeatured = nil
        self.dailyAlternatives = []
        // 冷启动就带上会话种子；日推与发现流错开，减少首屏撞车。
        let sessionSeed = Self.makeSessionSeed()
        self.dailyBatch = sessionSeed % 30
        self.preferredFlavors = []
        self.isLoadingDaily = false
        self.isLoading = isLoading
        self.isLoadingMore = false
        self.hasMoreFeed = false
        self.feedSeed = sessionSeed + 41
        self.isSearching = isSearching
        self.isFetchingSuggestions = false
        self.errorMessage = errorMessage
        self.searchErrorMessage = nil
        self.lastSubmittedQuery = nil
    }

    private static func makeSessionSeed() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let hour = calendar.component(.hour, from: now)
        let minuteBucket = calendar.component(.minute, from: now) / 5
        return day * 1000 + hour * 20 + minuteBucket + Int.random(in: 0...199)
    }

    /// 今天吃点什么里已出现的菜，发现流要避开。
    var dailyOccupiedIDs: Set<Int> {
        Set((dailyItems + dailyAlternatives).map(\.id))
    }

    func setSelectedIngredientNames(_ names: [String]) {
        selectedIngredientNames = Self.normalizedNames(from: names)
        Task { await refreshForCurrentContext() }
    }

    func clearSelectedIngredientNames() {
        selectedIngredientNames = []
        Task { await refreshDefaultFeed() }
    }

    func loadFeedIfNeeded() async {
        guard !hasLoadedFeed, !isLoading else { return }
        await refreshForCurrentContext()
    }

    func loadMoreFeedIfNeeded(currentRecipeID: Int?) async {
        guard selectedIngredientNames.isEmpty else { return }
        guard hasMoreFeed, !isLoading, !isLoadingMore else { return }
        guard let currentRecipeID else { return }
        guard rawFeed.suffix(4).contains(where: { $0.id == currentRecipeID }) else { return }

        isLoadingMore = true
        let excludeIDs = Array(dailyOccupiedIDs)

        do {
            let response = try await service.fetchRecommendationFeed(
                page: feedPage + 1,
                seed: feedSeed,
                excludeIDs: excludeIDs
            )
            feedPage = response.data.page
            hasMoreFeed = response.data.hasMore
            let blocked = dailyOccupiedIDs.union(Set(rawFeed.map(\.id)))
            let incoming = response.data.items.filter { !blocked.contains($0.id) }
            rawFeed.append(contentsOf: incoming)
            feed = applyInteractionState(to: rawFeed)
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoadingMore = false
    }

    func loadHotSearchesIfNeeded() async {
        guard !hasLoadedHotSearches else { return }
        await refreshHotSearches()
    }

    func loadDailyIfNeeded(ingredientNames: [String] = []) async {
        guard !hasLoadedDaily, !isLoadingDaily else { return }
        await refreshDaily(ingredientNames: ingredientNames)
    }

    func refreshDaily(ingredientNames: [String] = [], batch: Int? = nil, rotate: Bool = false) async {
        isLoadingDaily = true
        let previousPrimary = Set(dailyItems.map(\.id))
        let previousSecondary = Set(dailyAlternatives.map(\.id))
        let nextBatch: Int = {
            if let batch { return max(0, batch) }
            if rotate { return dailyBatch + 1 }
            return dailyBatch
        }()

        do {
            let response = try await service.fetchDailyRecommendation(
                ingredients: Self.normalizedNames(from: ingredientNames),
                limit: 3,
                batch: nextBatch
            )
            var primary = applyInteractionState(to: response.data.primaryItems)
            var secondary = applyInteractionState(to: response.data.secondaryItems)

            // 旧服务端若仍把次推当成首推尾巴，强制拆开。
            if secondary.isEmpty, primary.count > 3 {
                secondary = Array(primary.dropFirst(3))
                primary = Array(primary.prefix(3))
            } else if secondary.isEmpty, primary.count > 1 {
                secondary = Array(primary.dropFirst())
                primary = Array(primary.prefix(max(1, primary.count / 2)))
            }
            let primaryIDs = Set(primary.map(\.id))
            secondary = secondary.filter { !primaryIDs.contains($0.id) }

            if primary.isEmpty && secondary.isEmpty {
                let fallback = try await fetchDailyFallback(batch: nextBatch, excluding: [])
                primary = fallback.primary
                secondary = fallback.secondary
            } else if rotate,
                      Set(primary.map(\.id)) == previousPrimary,
                      Set(secondary.map(\.id)) == previousSecondary {
                let fallback = try await fetchDailyFallback(
                    batch: nextBatch,
                    excluding: previousPrimary.union(previousSecondary)
                )
                if !fallback.primary.isEmpty || !fallback.secondary.isEmpty {
                    primary = fallback.primary
                    secondary = fallback.secondary
                }
            }

            applyDaily(primary: primary, secondary: secondary, batch: response.data.batch ?? nextBatch)
            preferredFlavors = response.data.preferredFlavors
        } catch {
            // daily 接口未部署/404 时，用 feed 专属种子兜底，保证首推/次推都能刷出来。
            do {
                let fallback = try await fetchDailyFallback(
                    batch: nextBatch,
                    excluding: rotate ? previousPrimary.union(previousSecondary) : []
                )
                applyDaily(primary: fallback.primary, secondary: fallback.secondary, batch: nextBatch)
            } catch {
                if rotate {
                    dailyBatch = nextBatch
                }
            }
        }

        isLoadingDaily = false
    }

    private func applyDaily(primary: [RecipeSummary], secondary: [RecipeSummary], batch: Int) {
        dailyItems = primary
        dailyFeatured = primary.first
        dailyAlternatives = secondary
        dailyBatch = batch
        hasLoadedDaily = true
        dedupeFeedAgainstDaily()
    }

    /// 当 daily 不可用时，用发现流接口另起种子，拆成首推（带图）+ 次推（标签）。
    private func fetchDailyFallback(
        batch: Int,
        excluding: Set<Int>
    ) async throws -> (primary: [RecipeSummary], secondary: [RecipeSummary]) {
        let seed = max(1, feedSeed + batch * 17 + 233)
        let response = try await service.fetchRecommendationFeed(
            page: 1,
            limit: 20,
            seed: seed,
            excludeIDs: Array(excluding)
        )
        // 过滤演示假数据，避免永远番茄炒蛋/青椒土豆丝。
        let fakeDemoIDs: Set<Int> = [101, 102, 103]
        let pool = response.data.items.filter { recipe in
            !excluding.contains(recipe.id) && !fakeDemoIDs.contains(recipe.id)
        }
        let primary = Array(pool.prefix(3))
        let secondary = Array(pool.dropFirst(3).prefix(8))
        return (applyInteractionState(to: primary), applyInteractionState(to: secondary))
    }

    func refreshForCurrentContext(rotateFeed: Bool = false) async {
        if selectedIngredientNames.isEmpty {
            await refreshDefaultFeed(rotate: rotateFeed)
        } else {
            await refreshFeedByIngredients()
        }
    }

    func retry() async {
        await refreshForCurrentContext(rotateFeed: true)
    }

    func retrySearch() async {
        await searchRecipes()
    }

    func applySearchKeyword(_ keyword: String) {
        query = keyword
    }

    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: Self.searchHistoryKey)
    }

    func clearSearchResults() {
        rawSearchResults = []
        searchResults = []
        searchSuggestions = []
        isSearching = false
        isFetchingSuggestions = false
        searchErrorMessage = nil
        lastSubmittedQuery = nil
        latestSuggestionQuery = nil
    }

    var hasCommittedSearchForCurrentQuery: Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedQuery.isEmpty && trimmedQuery == lastSubmittedQuery
    }

    func stateAdjustedRecipe(for recipe: RecipeSummary) -> RecipeSummary {
        applyInteractionState(to: recipe)
    }

    func setRecipeLiked(recipeID: Int, liked: Bool) {
        var state = interactionOverrides[recipeID] ?? InteractionState()
        state.liked = liked
        interactionOverrides[recipeID] = state
        refreshDisplayedRecipes()
    }

    func setRecipeFavorited(recipeID: Int, favorited: Bool) {
        var state = interactionOverrides[recipeID] ?? InteractionState()
        state.favorited = favorited
        interactionOverrides[recipeID] = state
        refreshDisplayedRecipes()
    }

    func applyProfileSnapshot(likedRecipeIDs: Set<Int>, favoritedRecipeIDs: Set<Int>) {
        let allRecipeIDs = likedRecipeIDs.union(favoritedRecipeIDs)
        interactionOverrides = [:]

        for recipeID in allRecipeIDs {
            interactionOverrides[recipeID] = InteractionState(
                liked: likedRecipeIDs.contains(recipeID),
                favorited: favoritedRecipeIDs.contains(recipeID)
            )
        }

        refreshDisplayedRecipes()
    }

    func clearInteractionState() {
        interactionOverrides = [:]
        refreshDisplayedRecipes()
    }

    func handleSearchQueryChanged(_ newValue: String) async {
        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            rawSearchResults = []
            searchResults = []
            searchSuggestions = []
            searchErrorMessage = nil
            lastSubmittedQuery = nil
            latestSuggestionQuery = nil
            isFetchingSuggestions = false
            return
        }

        if trimmedQuery != lastSubmittedQuery {
            rawSearchResults = []
            searchResults = []
            searchErrorMessage = nil
        }

        await refreshSearchSuggestions(for: trimmedQuery)
    }

    func searchRecipes() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            clearSearchResults()
            return
        }

        isSearching = true
        searchErrorMessage = nil
        lastSubmittedQuery = trimmedQuery

        do {
            let response = try await service.searchRecipes(query: trimmedQuery)
            rawSearchResults = response.data.recipes
            searchResults = applyInteractionState(to: rawSearchResults)
            appendSearchHistory(trimmedQuery)
        } catch {
            searchErrorMessage = error.localizedDescription
            rawSearchResults = []
            searchResults = []
        }

        isSearching = false
    }

    private func refreshDefaultFeed(rotate: Bool = false) async {
        isLoading = true
        errorMessage = nil
        feedPage = 0
        hasMoreFeed = false

        let nextSeed = rotate ? feedSeed + 1 : feedSeed
        let excludeIDs = Array(dailyOccupiedIDs)

        do {
            var response = try await service.fetchRecommendationFeed(
                page: 1,
                seed: nextSeed,
                excludeIDs: excludeIDs
            )
            var items = response.data.items.filter { !dailyOccupiedIDs.contains($0.id) }

            // 旧服务端忽略 seed 时会返回同一页；再按 seed 跳页，保证下拉能看到新菜。
            if rotate,
               !items.isEmpty,
               items.map(\.id) == rawFeed.prefix(items.count).map(\.id) {
                let jumpPage = (nextSeed % 400) + 1
                response = try await service.fetchRecommendationFeed(
                    page: jumpPage,
                    seed: 0,
                    excludeIDs: excludeIDs
                )
                items = response.data.items.filter { !dailyOccupiedIDs.contains($0.id) }
            }

            feedPage = max(1, response.data.page)
            hasMoreFeed = response.data.hasMore
            feedSeed = nextSeed
            rawFeed = items
            feed = applyInteractionState(to: rawFeed)
            hasLoadedFeed = true
        } catch {
            errorMessage = error.localizedDescription
            if rotate, !rawFeed.isEmpty {
                let shift = min(rawFeed.count, max(3, rawFeed.count / 2))
                rawFeed = Array(rawFeed.dropFirst(shift)) + Array(rawFeed.prefix(shift))
                feed = applyInteractionState(to: rawFeed)
                feedSeed = nextSeed
            }
        }

        isLoading = false
    }

    private func dedupeFeedAgainstDaily() {
        let blocked = dailyOccupiedIDs
        guard !blocked.isEmpty, !rawFeed.isEmpty else { return }
        let filtered = rawFeed.filter { !blocked.contains($0.id) }
        guard filtered.count != rawFeed.count else { return }
        rawFeed = filtered
        feed = applyInteractionState(to: rawFeed)
    }

    private func refreshFeedByIngredients() async {
        isLoading = true
        errorMessage = nil
        feedPage = 0
        hasMoreFeed = false

        do {
            let response = try await service.fetchByIngredients(selectedIngredientNames)
            rawFeed = response.data.recipes
            feed = applyInteractionState(to: rawFeed)
            hasLoadedFeed = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func refreshHotSearches() async {
        do {
            let response = try await service.fetchHotSearches()
            hotSearches = response.data.map(\.keyword)
        } catch {
            if hotSearches.isEmpty {
                hotSearches = Self.sampleHotSearches
            }
        }

        hasLoadedHotSearches = true
    }

    private func refreshSearchSuggestions(for query: String) async {
        latestSuggestionQuery = query
        isFetchingSuggestions = true

        do {
            let response = try await service.fetchSearchSuggestions(query: query)
            guard latestSuggestionQuery == query else { return }
            searchSuggestions = mergedSuggestionList(
                remote: response.data,
                query: query
            )
        } catch {
            guard latestSuggestionQuery == query else { return }
            searchSuggestions = mergedSuggestionList(
                remote: [],
                query: query
            )
        }

        if latestSuggestionQuery == query {
            isFetchingSuggestions = false
        }
    }

    private static func normalizedNames(from names: [String]) -> [String] {
        var seen = Set<String>()

        return names.compactMap { rawValue in
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }

    private func applyInteractionState(to recipes: [RecipeSummary]) -> [RecipeSummary] {
        recipes.map(applyInteractionState(to:))
    }

    private func applyInteractionState(to recipe: RecipeSummary) -> RecipeSummary {
        guard let override = interactionOverrides[recipe.id] else { return recipe }

        var updated = recipe
        if let liked = override.liked {
            updated.liked = liked
        }
        if let favorited = override.favorited {
            updated.favorited = favorited
        }
        return updated
    }

    private func refreshDisplayedRecipes() {
        feed = applyInteractionState(to: rawFeed)
        searchResults = applyInteractionState(to: rawSearchResults)
        dailyItems = applyInteractionState(to: dailyItems)
        dailyAlternatives = applyInteractionState(to: dailyAlternatives)
        dailyFeatured = dailyItems.first
    }

    private func mergedSuggestionList(remote: [String], query: String) -> [String] {
        let localCandidates = (searchHistory + hotSearches + feed.map(\.title))
            .filter { $0.localizedCaseInsensitiveContains(query) }

        var seen = Set<String>()

        return (remote + localCandidates).compactMap { item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }

    private func appendSearchHistory(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        searchHistory.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        searchHistory.insert(trimmed, at: 0)

        if searchHistory.count > Self.maxSearchHistoryCount {
            searchHistory = Array(searchHistory.prefix(Self.maxSearchHistoryCount))
        }

        UserDefaults.standard.set(searchHistory, forKey: Self.searchHistoryKey)
    }

    private static func loadSearchHistory() -> [String] {
        guard let stored = UserDefaults.standard.array(forKey: Self.searchHistoryKey) as? [String] else {
            return []
        }

        return stored.compactMap { item in
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

extension RecommendationStore {
    nonisolated static let sampleHotSearches: [String] = [
        "番茄炒蛋",
        "土豆炖牛肉",
        "鸡蛋羹",
        "凉拌黄瓜",
        "青椒肉丝"
    ]

    nonisolated static let sampleFeed: [RecipeSummary] = [
        RecipeSummary(
            id: 101,
            title: "番茄炒蛋",
            coverURL: nil,
            matchReason: "适合从常见家常食材快速开做",
            heat: 128,
            liked: false,
            favorited: true
        ),
        RecipeSummary(
            id: 102,
            title: "青椒土豆丝",
            coverURL: nil,
            matchReason: "适合清库存，做法也比较稳",
            heat: 96,
            liked: false,
            favorited: false
        ),
        RecipeSummary(
            id: 103,
            title: "土豆炖牛肉",
            coverURL: nil,
            matchReason: "适合一次消耗多种主食材",
            heat: 210,
            liked: true,
            favorited: true
        ),
    ]
}
