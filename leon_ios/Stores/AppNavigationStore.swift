import Foundation
import Combine

@MainActor
final class AppNavigationStore: ObservableObject {
    @Published var selectedTab: AppTab

    init(selectedTab: AppTab = .ingredients) {
        self.selectedTab = selectedTab
    }

    func switchToRecommend() {
        selectedTab = .recommend
    }

    func switchToIngredients() {
        selectedTab = .ingredients
    }

    func switchToMe() {
        selectedTab = .me
    }
}
