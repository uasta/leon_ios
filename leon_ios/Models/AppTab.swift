import Foundation

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case ingredients
    case recommend
    case explore
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ingredients:
            return L10n.text(L10n.Tab.ingredients)
        case .recommend:
            return L10n.text(L10n.Tab.recommend)
        case .explore:
            return L10n.text(L10n.Tab.explore)
        case .me:
            return L10n.text(L10n.Tab.me)
        }
    }

    var systemImage: String {
        switch self {
        case .ingredients:
            return "carrot"
        case .recommend:
            return "fork.knife"
        case .explore:
            return "sparkles"
        case .me:
            return "person.crop.circle"
        }
    }

    static let defaultOrder: [AppTab] = [.ingredients, .recommend, .explore, .me]
}
