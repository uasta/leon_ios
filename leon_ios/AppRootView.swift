import SwiftUI

struct AppRootView: View {
    @StateObject private var ingredientStore = IngredientStore()
    @StateObject private var presetStore = IngredientPresetStore()

    var body: some View {
        TabView {
            IngredientsListView()
                .tabItem {
                    Label("食材", systemImage: "carrot")
                }

            RemindersView()
                .tabItem {
                    Label("提醒", systemImage: "bell")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .environmentObject(ingredientStore)
        .environmentObject(presetStore)
    }
}

#Preview {
    AppRootView()
}

