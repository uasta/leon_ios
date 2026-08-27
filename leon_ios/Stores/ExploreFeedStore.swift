import Foundation
import Combine

@MainActor
final class ExploreFeedStore: ObservableObject {
    @Published private(set) var items: [ExploreVideoItem]
    @Published var currentID: UUID?
    @Published private(set) var likedIDs: Set<UUID> = []

    private let preloadRadius = 1
    private let appendThreshold = 3

    init() {
        let batch = ExploreMockCatalog.makeBatch()
        items = batch
        currentID = batch.first?.id
    }

    var currentItem: ExploreVideoItem? {
        guard let currentID else { return items.first }
        return items.first { $0.id == currentID } ?? items.first
    }

    var currentIndex: Int {
        guard let currentID else { return 0 }
        return items.firstIndex { $0.id == currentID } ?? 0
    }

    func windowItems() -> [ExploreVideoItem] {
        let index = currentIndex
        let lower = max(0, index - preloadRadius)
        let upper = min(items.count - 1, index + preloadRadius)
        guard lower <= upper else { return [] }
        return Array(items[lower...upper])
    }

    func appendIfNeeded() {
        guard currentIndex >= items.count - appendThreshold else { return }
        items.append(contentsOf: ExploreMockCatalog.makeBatch())
    }

    func toggleLike(for id: UUID) {
        if likedIDs.contains(id) {
            likedIDs.remove(id)
        } else {
            likedIDs.insert(id)
        }
    }

    func isLiked(_ id: UUID) -> Bool {
        likedIDs.contains(id)
    }
}
