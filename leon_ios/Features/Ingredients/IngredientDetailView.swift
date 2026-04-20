import SwiftUI

struct IngredientDetailView: View {
    @EnvironmentObject private var store: IngredientStore
    let ingredientID: Ingredient.ID

    @State private var showEditor: Bool = false

    private var ingredient: Ingredient? {
        store.items.first { $0.id == ingredientID }
    }

    var body: some View {
        Group {
            if let ingredient {
                List {
                    Section {
                        LabeledContent("数量", value: ingredient.quantityText)
                        LabeledContent("位置", value: ingredient.location.rawValue)
                    }

                    Section("到期") {
                        LabeledContent("到期日", value: expiryText(for: ingredient))
                        LabeledContent("状态", value: freshnessText(for: ingredient))
                    }

                    if !ingredient.tags.isEmpty {
                        Section("标签") {
                            Text(ingredient.tags.joined(separator: "、"))
                        }
                    }

                    if !ingredient.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section("备注") {
                            Text(ingredient.note)
                        }
                    }

                    Section {
                        Button {
                            store.archive(ingredient.id)
                        } label: {
                            Label("标记为已用完（归档）", systemImage: "checkmark.circle")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            store.delete(ingredient.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(ingredient.name)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") { showEditor = true }
                    }
                }
                .sheet(isPresented: $showEditor) {
                    IngredientEditorView(ingredient: ingredient)
                }
            } else {
                ContentUnavailableView("找不到该食材", systemImage: "questionmark.folder")
            }
        }
    }

    private func expiryText(for ingredient: Ingredient) -> String {
        guard let date = ingredient.expiryDate else { return "无" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func freshnessText(for ingredient: Ingredient) -> String {
        switch ingredient.freshness {
        case .expired:
            return "已过期"
        case .expiringSoon(let daysLeft):
            return daysLeft == 0 ? "今天到期" : "临期（剩 \(daysLeft) 天）"
        case .fresh:
            return "新鲜"
        case .noExpiry:
            return "不提醒"
        }
    }
}

#Preview {
    NavigationStack {
        IngredientDetailView(ingredientID: IngredientStore.sampleItems[0].id)
            .environmentObject(IngredientStore())
            .environmentObject(IngredientPresetStore())
    }
}

