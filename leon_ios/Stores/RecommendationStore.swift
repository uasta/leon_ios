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
    @Published private(set) var isLoading: Bool
    @Published private(set) var isLoadingMore: Bool
    @Published private(set) var hasMoreFeed: Bool
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
    private var interactionOverrides: [Int: InteractionState] = [:]
    private var latestSuggestionQuery: String?

    init(
        service: RecommendationService = RecommendationService(client: APIClient()),
        feed: [RecipeSummary] = RecommendationStore.sampleFeed,
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
        self.isLoading = isLoading
        self.isLoadingMore = false
        self.hasMoreFeed = false
        self.isSearching = isSearching
        self.isFetchingSuggestions = false
        self.errorMessage = errorMessage
        self.searchErrorMessage = nil
        self.lastSubmittedQuery = nil
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

        do {
            let response = try await service.fetchRecommendationFeed(page: feedPage + 1)
            feedPage = response.data.page
            hasMoreFeed = response.data.hasMore
            rawFeed.append(contentsOf: response.data.items)
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

    func refreshForCurrentContext() async {
        if selectedIngredientNames.isEmpty {
            await refreshDefaultFeed()
        } else {
            await refreshFeedByIngredients()
        }
    }

    func retry() async {
        await refreshForCurrentContext()
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

    private func refreshDefaultFeed() async {
        isLoading = true
        errorMessage = nil
        feedPage = 0
        hasMoreFeed = false

        do {
            let response = try await service.fetchRecommendationFeed(page: 1)
            feedPage = response.data.page
            hasMoreFeed = response.data.hasMore
            rawFeed = response.data.items
            feed = applyInteractionState(to: rawFeed)
            hasLoadedFeed = true
        } catch {
            errorMessage = error.localizedDescription
            if feed.isEmpty {
                rawFeed = Self.sampleFeed
                feed = applyInteractionState(to: rawFeed)
            }
        }

        isLoading = false
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
            if feed.isEmpty {
                rawFeed = Self.sampleFeed
                feed = applyInteractionState(to: rawFeed)
            }
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
            liked: false,
            favorited: true
        ),
        RecipeSummary(
            id: 102,
            title: "青椒土豆丝",
            coverURL: nil,
            matchReason: "适合清库存，做法也比较稳",
            liked: false,
            favorited: false
        ),
        RecipeSummary(
            id: 103,
            title: "土豆炖牛肉",
            coverURL: nil,
            matchReason: "适合一次消耗多种主食材",
            liked: true,
            favorited: true
        ),
    ]
}
