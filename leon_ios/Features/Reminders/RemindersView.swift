import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var store: IngredientStore
    @Environment(\.colorScheme) private var colorScheme

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
                        L10n.text(L10n.Reminders.emptyTitle),
                        systemImage: "bell",
                        description: Text(L10n.text(L10n.Reminders.emptySubtitle))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !expiringSoon.isEmpty || !expired.isEmpty {
                            Section {
                                reminderSummary
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .listRowBackground(Color.clear)
                            }
                        }

                        if !expiringSoon.isEmpty {
                            Section {
                                ForEach(expiringSoon) { item in
                                    NavigationLink(value: item) {
                                        reminderRow(item: item, tone: AppTheme.warning)
                                    }
                                    .swipeActions {
                                        Button {
                                            store.archive(item.id)
                                        } label: {
                                            Label(L10n.text(L10n.Action.markUsed), systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)

                                        Button {
                                            store.postponeExpiry(item.id, days: 1)
                                        } label: {
                                            Label(L10n.text(L10n.Ingredients.postpone1d), systemImage: "calendar.badge.plus")
                                        }
                                        .tint(AppTheme.accent)
                                    }
                                }
                            } header: {
                                Text(L10n.text(L10n.Ingredients.statusExpiring))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.warning)
                                    .textCase(nil)
                            }
                            .listRowBackground(AppTheme.sectionBackground(for: .expiring, scheme: colorScheme))
                        }

                        if !expired.isEmpty {
                            Section {
                                ForEach(expired) { item in
                                    NavigationLink(value: item) {
                                        reminderRow(item: item, tone: AppTheme.danger)
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            store.delete(item.id)
                                        } label: {
                                            Label(L10n.text(L10n.Action.delete), systemImage: "trash.fill")
                                        }
                                    }
                                }
                            } header: {
                                Text(L10n.text(L10n.Ingredients.statusExpired))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.danger)
                                    .textCase(nil)
                            }
                            .listRowBackground(AppTheme.sectionBackground(for: .expired, scheme: colorScheme))
                        }

                        Section {
                            Text(L10n.text(L10n.Reminders.footer))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .appScreenBackground()
            .navigationTitle(L10n.text(L10n.Reminders.title))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Ingredient.self) { ingredient in
                IngredientDetailView(ingredientID: ingredient.id)
            }
        }
    }

    private var reminderSummary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Reminders.summaryCount(expiringSoon.count + expired.count))
                    .font(.headline)

                Text(L10n.text(L10n.Reminders.summaryHint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !expiringSoon.isEmpty {
                summaryChip(L10n.Reminders.chipExpiring(expiringSoon.count), color: AppTheme.warning)
            }

            if !expired.isEmpty {
                summaryChip(L10n.Reminders.chipExpired(expired.count), color: AppTheme.danger)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private func summaryChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func reminderRow(item: Ingredient, tone: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tone.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: item.location.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(item.quantityText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(tone)
                    Text(expiryText(for: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(item.location.localizedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func expiryText(for item: Ingredient) -> String {
        guard let date = item.expiryDate else { return L10n.text(L10n.Ingredients.statusNoExpiry) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    RemindersView()
        .environmentObject(IngredientStore())
        .environmentObject(IngredientPresetStore())
}
