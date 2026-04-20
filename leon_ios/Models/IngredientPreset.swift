import Foundation

struct IngredientPreset: Identifiable, Hashable {
    enum Icon: Hashable {
        case system(name: String)
        case asset(name: String)
    }

    let id: UUID
    var name: String
    var defaultUnit: String
    var defaultLocation: Ingredient.Location
    var icon: Icon
    var defaultExpiryDays: Int?
    var tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        defaultUnit: String,
        defaultLocation: Ingredient.Location,
        icon: Icon = .system(name: "carrot"),
        defaultExpiryDays: Int? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.defaultUnit = defaultUnit
        self.defaultLocation = defaultLocation
        self.icon = icon
        self.defaultExpiryDays = defaultExpiryDays
        self.tags = tags
    }
}

