import SwiftUI

struct RecommendHomeView: View {
    @EnvironmentObject private var store: RecommendationStore

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]
    private let hotSearchColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 10, alignment: .leading)
    ]

    private var trimmedQuery: String {
        store.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isShowingSearchMode: Bool {
        !trimmedQuery.isEmpty || store.isSearching || !store.searchResults.isEmpty || store.searchErrorMessage != nil
    }

    private var activeRecipes: [RecipeSummary] {
        isShowingSearchMode ? store.searchResults : store.feed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if !store.selectedIngredientNames.isEmpty {
                        contextSection
                    }

                    if let errorMessage = store.errorMessage, !isShowingSearchMode {
                        statusSection(title: "推荐服务状态", message: errorMessage) {
                            await store.retry()
                        }
                    }

                    if isShowingSearchMode {
                        searchSection
                    } else {
                        hotSearchSection
                        recommendationSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("推荐")
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .searchable(text: $store.query, prompt: "搜索菜谱")
            .onSubmit(of: .search) {
                Task {
                    await store.searchRecipes()
                }
            }
            .onChange(of: store.query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    store.clearSearchResults()
                }
            }
            .refreshable {
                if isShowingSearchMode {
                    await store.retrySearch()
                } else {
                    await store.retry()
                }
            }
            .task {
                await store.loadFeedIfNeeded()
                await store.loadHotSearchesIfNeeded()
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("当前食材上下文", actionTitle: "清除") {
                store.clearSelectedIngredientNames()
            }

            Text("已带入 \(store.selectedIngredientNames.count) 个食材：\(store.selectedIngredientNames.joined(separator: "、"))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var hotSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("热门搜索")

            LazyVGrid(columns: hotSearchColumns, alignment: .leading, spacing: 10) {
                ForEach(store.hotSearches, id: \.self) { keyword in
                    Button(keyword) {
                        store.applySearchKeyword(keyword)
                        Task {
                            await store.searchRecipes()
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(store.selectedIngredientNames.isEmpty ? "为你推荐" : "按食材推荐")

            if store.isLoading && store.feed.isEmpty {
                ProgressView("正在准备推荐")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if activeRecipes.isEmpty {
                ContentUnavailableView(
                    "还没有推荐结果",
                    systemImage: "fork.knife",
                    description: Text("可以先从食材页带入几个食材，或者直接搜索菜谱。")
                )
            } else {
                recipeGrid(activeRecipes)
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("搜索结果", actionTitle: "搜索") {
                Task {
                    await store.searchRecipes()
                }
            }

            Text("关键词：\(trimmedQuery)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.isSearching && store.searchResults.isEmpty {
                ProgressView("正在搜索菜谱")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if let errorMessage = store.searchErrorMessage {
                statusSection(title: "搜索服务状态", message: errorMessage) {
                    await store.retrySearch()
                }
            } else if store.searchResults.isEmpty {
                ContentUnavailableView(
                    "没有找到结果",
                    systemImage: "magnifyingglass",
                    description: Text("换个关键词试试，或者点上方热门搜索继续看。")
                )
            } else {
                Text("共 \(store.searchResults.count) 条结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                recipeGrid(store.searchResults)
            }
        }
    }

    private func recipeGrid(_ recipes: [RecipeSummary]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(recipes) { recipe in
                NavigationLink(value: recipe) {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionHeader(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption)
            }
        }
    }

    private func statusSection(title: String, message: String, retry: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("重试加载") {
                Task {
                    await retry()
                }
            }
            .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RecipeCard: View {
    let recipe: RecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 14)
                .fill(cardGradient)
                .frame(height: 118)
                .overlay(alignment: .bottomLeading) {
                    Text(cardBadgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.18), in: Capsule())
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(recipe.matchReason ?? "等待真实推荐理由")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var cardBadgeText: String {
        if recipe.favorited {
            return "已收藏"
        }

        if recipe.liked {
            return "高匹配"
        }

        return "家常推荐"
    }

    private var cardGradient: LinearGradient {
        if recipe.favorited {
            return LinearGradient(colors: [Color(red: 0.22, green: 0.48, blue: 0.78), Color(red: 0.38, green: 0.73, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        if recipe.liked {
            return LinearGradient(colors: [Color(red: 0.85, green: 0.46, blue: 0.21), Color(red: 0.96, green: 0.72, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        return LinearGradient(colors: [Color(red: 0.23, green: 0.62, blue: 0.47), Color(red: 0.74, green: 0.83, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview {
    RecommendHomeView()
        .environmentObject(RecommendationStore())
        .environmentObject(SessionStore())
}
