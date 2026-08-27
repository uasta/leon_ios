import SwiftUI

struct IngredientDetailView: View {
    @EnvironmentObject private var store: IngredientStore
    @EnvironmentObject private var presetStore: IngredientPresetStore
    @Environment(\.dismiss) private var dismiss

    let ingredientID: Ingredient.ID

    @State private var showEditor: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var ingredient: Ingredient? {
        store.items.first { $0.id == ingredientID }
    }

    var body: some View {
        Group {
            if let ingredient {
                List {
                    Section {
                        IngredientStatusHeader(ingredient: ingredient)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        LabeledContent(L10n.text(L10n.Action.quantity), value: ingredient.quantityText)
                        LabeledContent(L10n.text(L10n.Action.location), value: ingredient.location.localizedTitle)
                    }

                    Section(L10n.text(L10n.Ingredients.detailExpirySection)) {
                        LabeledContent(L10n.text(L10n.Ingredients.expiryDate), value: expiryText(for: ingredient))
                        LabeledContent(L10n.text(L10n.Action.status), value: freshnessText(for: ingredient))
                    }

                    if !ingredient.tags.isEmpty {
                        Section(L10n.text(L10n.Action.tags)) {
                            Text(ingredient.tags.joined(separator: "、"))
                        }
                    }

                    if !ingredient.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section(L10n.text(L10n.Action.note)) {
                            Text(ingredient.note)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button {
                            store.archive(ingredient.id)
                            dismiss()
                        } label: {
                            Label(L10n.text(L10n.Ingredients.detailArchive), systemImage: "checkmark.circle")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(L10n.text(L10n.Action.delete), systemImage: "trash")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .appScreenBackground()
                .navigationTitle(ingredient.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.text(L10n.Action.edit)) { showEditor = true }
                            .fontWeight(.semibold)
                    }
                }
                .sheet(isPresented: $showEditor) {
                    IngredientEditorView(ingredient: ingredient)
                        .environmentObject(store)
                        .environmentObject(presetStore)
                }
                .confirmationDialog(
                    L10n.Ingredients.deleteConfirm(ingredient.name),
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button(L10n.text(L10n.Action.delete), role: .destructive) {
                        store.delete(ingredient.id)
                        dismiss()
                    }
                }
            } else {
                ContentUnavailableView(L10n.text(L10n.Ingredients.detailNotFound), systemImage: "questionmark.folder")
            }
        }
    }

    private func expiryText(for ingredient: Ingredient) -> String {
        guard let date = ingredient.expiryDate else { return L10n.text(L10n.Ingredients.detailExpiryNone) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func freshnessText(for ingredient: Ingredient) -> String {
        switch ingredient.freshness {
        case .expired:
            return L10n.text(L10n.Ingredients.freshnessExpired)
        case .expiringSoon(let daysLeft):
            return daysLeft == 0
                ? L10n.text(L10n.Ingredients.freshnessExpiresToday)
                : L10n.Ingredients.freshnessExpiring(daysLeft)
        case .fresh:
            return L10n.text(L10n.Ingredients.freshnessFresh)
        case .noExpiry:
            return L10n.text(L10n.Ingredients.freshnessNoReminder)
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
