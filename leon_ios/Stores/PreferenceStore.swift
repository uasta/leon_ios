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

    /// 同步给后端的 Tab 顺序。开拓暂未接入偏好接口，避免校验失败。
    var syncableTabOrder: [AppTab] {
        tabOrder.filter { $0 != .explore }
    }

    func setPreferRecommendFirst(_ enabled: Bool) {
        let nextOrder: [AppTab] = enabled
            ? [.recommend, .explore, .ingredients, .me]
            : AppTab.defaultOrder
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
        let recommendIndex = rawValue.firstIndex(of: .recommend) ?? .max
        let ingredientsIndex = rawValue.firstIndex(of: .ingredients) ?? .max
        if recommendIndex < ingredientsIndex {
            return [.recommend, .explore, .ingredients, .me]
        }
        return AppTab.defaultOrder
    }
}
