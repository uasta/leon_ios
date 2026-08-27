import SwiftUI

struct AppRootView: View {
    @StateObject private var ingredientStore = IngredientStore()
    @StateObject private var presetStore = IngredientPresetStore()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var preferenceStore = PreferenceStore()
    @StateObject private var recommendationStore = RecommendationStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var navigationStore = AppNavigationStore()
    @ObservedObject private var languageStore = LanguageStore.shared

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
        .tint(AppTheme.accent)
        .environmentObject(ingredientStore)
        .environmentObject(presetStore)
        .environmentObject(sessionStore)
        .environmentObject(preferenceStore)
        .environmentObject(recommendationStore)
        .environmentObject(profileStore)
        .environmentObject(navigationStore)
        .environmentObject(languageStore)
        .environment(\.locale, languageStore.resolvedLocale)
        .id(languageStore.language.rawValue)
        .onAppear {
            navigationStore.selectedTab = preferenceStore.tabOrder.first ?? .ingredients
        }
        .onReceive(NotificationCenter.default.publisher(for: .leonSessionUnauthorized)) { _ in
            handleUnauthorizedSession()
        }
        .onChange(of: preferenceStore.tabOrder) { _, newValue in
            guard let first = newValue.first else { return }
            if !newValue.contains(navigationStore.selectedTab) {
                navigationStore.selectedTab = first
            }
        }
    }

    private func handleUnauthorizedSession() {
        guard sessionStore.isAuthenticated || sessionStore.accessToken != nil else { return }
        sessionStore.clearSession()
        profileStore.resetToLocalPreview()
        recommendationStore.clearInteractionState()
    }

    @ViewBuilder
    private func tabRoot(for tab: AppTab) -> some View {
        switch tab {
        case .ingredients:
            IngredientsListView()
        case .recommend:
            RecommendHomeView()
        case .explore:
            ExploreFeedView()
        case .me:
            MeHomeView()
        }
    }
}

#Preview {
    AppRootView()
}
