import Foundation
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var likes: [RecipeSummary]
    @Published private(set) var favorites: [RecipeSummary]
    @Published private(set) var history: [RecipeSummary]
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var syncMessage: String?

    private let service: ProfileService
    private var hasLoaded = false

    init(
        service: ProfileService = ProfileService(client: APIClient()),
        likes: [RecipeSummary] = Array(RecommendationStore.sampleFeed.prefix(1)),
        favorites: [RecipeSummary] = Array(RecommendationStore.sampleFeed.prefix(2)),
        history: [RecipeSummary] = RecommendationStore.sampleFeed,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        syncMessage: String? = nil
    ) {
        self.service = service
        self.likes = likes
        self.favorites = favorites
        self.history = history
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.syncMessage = syncMessage
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let likesResponse = service.fetchLikes()
            async let favoritesResponse = service.fetchFavorites()
            async let historyResponse = service.fetchHistory()

            let likesEnvelope = try await likesResponse
            let favoritesEnvelope = try await favoritesResponse
            let historyEnvelope = try await historyResponse

            likes = likesEnvelope.data
            favorites = favoritesEnvelope.data
            history = historyEnvelope.data
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func resetToLocalPreview() {
        likes = Array(RecommendationStore.sampleFeed.prefix(1))
        favorites = Array(RecommendationStore.sampleFeed.prefix(2))
        history = RecommendationStore.sampleFeed
        errorMessage = nil
        syncMessage = nil
        isLoading = false
        hasLoaded = false
    }

    func markSyncMessage(_ message: String?) {
        syncMessage = message
    }

    func setRecipeLiked(recipeID: Int, liked: Bool, fallback: RecipeSummary? = nil) {
        favorites = updateSummaryCollection(favorites, recipeID: recipeID, liked: liked)
        history = updateSummaryCollection(history, recipeID: recipeID, liked: liked)

        if liked {
            if let existingIndex = likes.firstIndex(where: { $0.id == recipeID }) {
                likes[existingIndex].liked = true
            } else if let fallback {
                var inserted = fallback
                inserted.liked = true
                likes.insert(inserted, at: 0)
            }
        } else {
            likes.removeAll { $0.id == recipeID }
        }
    }

    func setRecipeFavorited(recipeID: Int, favorited: Bool, fallback: RecipeSummary? = nil) {
        likes = updateSummaryCollection(likes, recipeID: recipeID, favorited: favorited)
        history = updateSummaryCollection(history, recipeID: recipeID, favorited: favorited)

        if favorited {
            if let existingIndex = favorites.firstIndex(where: { $0.id == recipeID }) {
                favorites[existingIndex].favorited = true
            } else if let fallback {
                var inserted = fallback
                inserted.favorited = true
                favorites.insert(inserted, at: 0)
            }
        } else {
            favorites.removeAll { $0.id == recipeID }
        }
    }

    func addToHistory(_ recipe: RecipeSummary) {
        history.removeAll { $0.id == recipe.id }
        history.insert(recipe, at: 0)
    }

    var likedRecipeIDs: Set<Int> {
        Set(likes.map(\.id))
    }

    var favoritedRecipeIDs: Set<Int> {
        Set(favorites.map(\.id))
    }

    private func updateSummaryCollection(
        _ items: [RecipeSummary],
        recipeID: Int,
        liked: Bool? = nil,
        favorited: Bool? = nil
    ) -> [RecipeSummary] {
        items.map { item in
            guard item.id == recipeID else { return item }

            var updated = item
            if let liked {
                updated.liked = liked
            }
            if let favorited {
                updated.favorited = favorited
            }
            return updated
        }
    }
}
