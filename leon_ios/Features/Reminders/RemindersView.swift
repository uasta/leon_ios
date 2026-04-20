import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var store: IngredientStore

    private var expiringSoon: [Ingredient] {
        store.items
            .filter { !$0.isArchived }
            .filter {
                if case .expiringSoon = $0.freshness { return true }
                return false
            }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
    }

    private var expired: [Ingredient] {
        store.items
            .filter { !$0.isArchived }
            .filter { $0.freshness == .expired }
            .sorted { ($0.expiryDate ?? .distantPast) > ($1.expiryDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if expiringSoon.isEmpty && expired.isEmpty {
                    ContentUnavailableView(
                        "暂无提醒",
                        systemImage: "bell",
                        description: Text("设置到期日后，这里会自动聚合临期与过期食材。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !expiringSoon.isEmpty {
                            Section("临期") {
                                ForEach(expiringSoon) { item in
                                    NavigationLink(value: item) {
                                        reminderRow(item: item, tone: .orange)
                                    }
                                    .swipeActions {
                                        Button {
                                            store.archive(item.id)
                                        } label: {
                                            Label("用掉", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)

                                        Button {
                                            store.postponeExpiry(item.id, days: 1)
                                        } label: {
                                            Label("延期 1 天", systemImage: "calendar.badge.plus")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                        }

                        if !expired.isEmpty {
                            Section("已过期") {
                                ForEach(expired) { item in
                                    NavigationLink(value: item) {
                                        reminderRow(item: item, tone: .red)
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            store.delete(item.id)
                                        } label: {
                                            Label("删除", systemImage: "trash.fill")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("提醒")
            .navigationDestination(for: Ingredient.self) { ingredient in
                IngredientDetailView(ingredientID: ingredient.id)
            }
        }
    }

    private func reminderRow(item: Ingredient, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                Text(item.quantityText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(tone)
                Text(expiryText(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.location.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func expiryText(for item: Ingredient) -> String {
        guard let date = item.expiryDate else { return "无到期日" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    RemindersView()
        .environmentObject(IngredientStore())
        .environmentObject(IngredientPresetStore())
}

