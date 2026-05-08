import SwiftUI

struct AppRootView: View {
    @StateObject private var ingredientStore = IngredientStore()
    @StateObject private var presetStore = IngredientPresetStore()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var preferenceStore = PreferenceStore()
    @StateObject private var recommendationStore = RecommendationStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var navigationStore = AppNavigationStore()

    var body: some View {
        TabView(selection: $navigationStore.selectedTab) {
            ForEach(preferenceStore.tabOrder) { tab in
                tabRoot(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .environmentObject(ingredientStore)
        .environmentObject(presetStore)
        .environmentObject(sessionStore)
        .environmentObject(preferenceStore)
        .environmentObject(recommendationStore)
        .environmentObject(profileStore)
        .environmentObject(navigationStore)
        .onAppear {
            navigationStore.selectedTab = preferenceStore.tabOrder.first ?? .ingredients
        }
        .onChange(of: preferenceStore.tabOrder) { _, newValue in
            guard let first = newValue.first else { return }
            if !newValue.contains(navigationStore.selectedTab) {
                navigationStore.selectedTab = first
            }
        }
    }

    @ViewBuilder
    private func tabRoot(for tab: AppTab) -> some View {
        switch tab {
        case .ingredients:
            IngredientsListView()
        case .recommend:
            RecommendHomeView()
        case .me:
            MeHomeView()
        }
    }
}

#Preview {
    AppRootView()
}
