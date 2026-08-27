import Foundation
import Combine

@MainActor
final class IngredientStore: ObservableObject {
    @Published private(set) var items: [Ingredient]

    private let storageKey = "ingredient.store.items"

    init(items: [Ingredient]? = nil) {
        if let items {
            self.items = items
        } else if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Ingredient].self, from: data)
        {
            self.items = decoded
        } else {
            self.items = IngredientStore.sampleItems
            persist()
        }
    }

    func add(_ ingredient: Ingredient) {
        items.insert(ingredient, at: 0)
        persist()
    }

    func addMany(_ ingredients: [Ingredient]) {
        guard !ingredients.isEmpty else { return }
        items.insert(contentsOf: ingredients, at: 0)
        persist()
    }

    func update(_ ingredient: Ingredient) {
        guard let idx = items.firstIndex(where: { $0.id == ingredient.id }) else { return }
        items[idx] = ingredient
        persist()
    }

    func archive(_ ingredientID: Ingredient.ID) {
        guard let idx = items.firstIndex(where: { $0.id == ingredientID }) else { return }
        items[idx].isArchived = true
        persist()
    }

    func delete(_ ingredientID: Ingredient.ID) {
        items.removeAll { $0.id == ingredientID }
        persist()
    }

    func postponeExpiry(_ ingredientID: Ingredient.ID, days: Int) {
        guard let idx = items.firstIndex(where: { $0.id == ingredientID }) else { return }
        guard let expiry = items[idx].expiryDate else { return }
        items[idx].expiryDate = Calendar.current.date(byAdding: .day, value: days, to: expiry)
        persist()
    }

    func replaceAll(_ ingredients: [Ingredient]) {
        items = ingredients
        persist()
    }

    func activeSyncDrafts() -> [IngredientSyncDraft] {
        items
            .filter { !$0.isArchived }
            .map(\.syncDraft)
            .filter { !$0.name.isEmpty }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

extension IngredientStore {
    nonisolated static var sampleItems: [Ingredient] {
        let cal = Calendar.current
        let now = Date()
        return [
            Ingredient(
                name: "牛肉",
                quantity: 0.5,
                unit: "kg",
                location: .fridgeFreeze,
                purchaseDate: cal.date(byAdding: .day, value: -3, to: now),
                expiryDate: cal.date(byAdding: .day, value: 6, to: now),
                tags: ["肉类"]
            ),
            Ingredient(
                name: "番茄",
                quantity: 4,
                unit: "个",
                location: .fridgeChill,
                purchaseDate: cal.date(byAdding: .day, value: -2, to: now),
                expiryDate: cal.date(byAdding: .day, value: 1, to: now),
                tags: ["蔬菜"]
            ),
            Ingredient(
                name: "鸡蛋",
                quantity: 12,
                unit: "枚",
                location: .fridgeChill,
                purchaseDate: cal.date(byAdding: .day, value: -7, to: now),
                expiryDate: cal.date(byAdding: .day, value: -1, to: now),
                tags: ["蛋奶"]
            ),
            Ingredient(
                name: "土豆",
                quantity: 6,
                unit: "个",
                location: .pantry,
                purchaseDate: cal.date(byAdding: .day, value: -4, to: now),
                expiryDate: cal.date(byAdding: .day, value: 10, to: now),
                tags: ["蔬菜"]
            ),
            Ingredient(
                name: "青椒",
                quantity: 3,
                unit: "个",
                location: .fridgeChill,
                purchaseDate: cal.date(byAdding: .day, value: -1, to: now),
                expiryDate: nil,
                note: "不提醒也行（演示无到期日）",
                tags: ["蔬菜"]
            )
        ]
    }
}
