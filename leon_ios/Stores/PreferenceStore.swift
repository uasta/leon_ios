import Foundation
import Combine

@MainActor
final class PreferenceStore: ObservableObject {
    @Published private(set) var tabOrder: [AppTab]

    private let tabOrderKey = "preference.tabOrder"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: tabOrderKey),
            let decoded = try? JSONDecoder().decode([AppTab].self, from: data)
        {
            self.tabOrder = Self.normalizedOrder(from: decoded)
        } else {
            self.tabOrder = AppTab.defaultOrder
        }
    }

    var preferRecommendFirst: Bool {
        tabOrder.first == .recommend
    }

    func setPreferRecommendFirst(_ enabled: Bool) {
        let nextOrder: [AppTab] = enabled
            ? [.recommend, .ingredients, .me]
            : [.ingredients, .recommend, .me]
        updateTabOrder(nextOrder)
    }

    func togglePrimaryTabsOrder() {
        setPreferRecommendFirst(!preferRecommendFirst)
    }

    func applyRemoteTabOrder(_ remoteValue: [AppTab]) {
        updateTabOrder(remoteValue)
    }

    private func updateTabOrder(_ newValue: [AppTab]) {
        let normalized = Self.normalizedOrder(from: newValue)
        tabOrder = normalized

        guard let data = try? JSONEncoder().encode(normalized) else { return }
        UserDefaults.standard.set(data, forKey: tabOrderKey)
    }

    private static func normalizedOrder(from rawValue: [AppTab]) -> [AppTab] {
        let primaryTabs = rawValue.filter { $0 != .me }
        if primaryTabs.first == .recommend {
            return [.recommend, .ingredients, .me]
        }
        return [.ingredients, .recommend, .me]
    }
}
