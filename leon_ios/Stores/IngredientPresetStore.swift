import Combine
import Foundation
import SwiftUI

@MainActor
final class IngredientPresetStore: ObservableObject {
    @Published var presets: [IngredientPreset]

    init(presets: [IngredientPreset] = IngredientPresetStore.defaultPresets) {
        self.presets = presets
    }

    func add(_ preset: IngredientPreset) {
        presets.insert(preset, at: 0)
    }

    func update(_ preset: IngredientPreset) {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = preset
    }

    func delete(_ id: IngredientPreset.ID) {
        presets.removeAll { $0.id == id }
    }

    func move(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
    }
}

extension IngredientPresetStore {
    nonisolated static var defaultPresets: [IngredientPreset] {
        [
            IngredientPreset(name: "鸡蛋", defaultUnit: "枚", defaultLocation: .fridgeChill, icon: .system(name: "oval.fill"), defaultExpiryDays: 14, tags: ["蛋奶"]),
            IngredientPreset(name: "牛奶", defaultUnit: "盒", defaultLocation: .fridgeChill, icon: .system(name: "carton.fill"), defaultExpiryDays: 7, tags: ["蛋奶"]),
            IngredientPreset(name: "番茄", defaultUnit: "个", defaultLocation: .fridgeChill, icon: .system(name: "leaf.fill"), defaultExpiryDays: 4, tags: ["蔬菜"]),
            IngredientPreset(name: "土豆", defaultUnit: "个", defaultLocation: .pantry, icon: .system(name: "shippingbox.fill"), defaultExpiryDays: 14, tags: ["蔬菜"]),
            IngredientPreset(name: "牛肉", defaultUnit: "kg", defaultLocation: .fridgeFreeze, icon: .system(name: "fork.knife"), defaultExpiryDays: 30, tags: ["肉类"])
        ]
    }
}

