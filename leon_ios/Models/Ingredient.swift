import Foundation

struct Ingredient: Identifiable, Hashable {
    enum Location: String, CaseIterable, Identifiable {
        case fridgeChill = "冰箱·冷藏"
        case fridgeFreeze = "冰箱·冷冻"
        case pantry = "常温·储物柜"
        case other = "其他"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .fridgeChill: return "snowflake"
            case .fridgeFreeze: return "cube.transparent"
            case .pantry: return "cabinet"
            case .other: return "tray"
            }
        }
    }

    let id: UUID
    var name: String
    var quantity: Double?
    var unit: String
    var location: Location
    var purchaseDate: Date?
    var expiryDate: Date?
    var note: String
    var tags: [String]
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double? = 1,
        unit: String = "份",
        location: Location = .fridgeChill,
        purchaseDate: Date? = nil,
        expiryDate: Date? = nil,
        note: String = "",
        tags: [String] = [],
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.location = location
        self.purchaseDate = purchaseDate
        self.expiryDate = expiryDate
        self.note = note
        self.tags = tags
        self.isArchived = isArchived
    }
}

extension Ingredient {
    enum Freshness: Comparable {
        case expired
        case expiringSoon(daysLeft: Int)
        case fresh
        case noExpiry
    }

    var freshness: Freshness {
        guard let expiryDate else { return .noExpiry }

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfExpiry = cal.startOfDay(for: expiryDate)
        let days = cal.dateComponents([.day], from: startOfToday, to: startOfExpiry).day ?? 0

        if days < 0 { return .expired }
        if days <= 2 { return .expiringSoon(daysLeft: days) }
        return .fresh
    }

    var quantityText: String {
        guard let quantity else { return "—" }
        let isInt = abs(quantity.rounded() - quantity) < 0.000_001
        let numberText = isInt ? String(Int(quantity)) : String(format: "%.1f", quantity)
        return "\(numberText)\(unit)"
    }
}

