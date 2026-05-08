import Foundation

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case ingredients
    case recommend
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ingredients:
            return "食材"
        case .recommend:
            return "推荐"
        case .me:
            return "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .ingredients:
            return "carrot"
        case .recommend:
            return "fork.knife"
        case .me:
            return "person.crop.circle"
        }
    }

    static let defaultOrder: [AppTab] = [.ingredients, .recommend, .me]
}
