import SwiftUI

struct AppScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.screenBackground(in: colorScheme).ignoresSafeArea())
    }
}

struct AppListSubtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}

struct FreshnessBadge: View {
    let freshness: Ingredient.Freshness

    var body: some View {
        switch freshness {
        case .expired:
            badge(L10n.text(L10n.Ingredients.freshnessExpiredShort), color: AppTheme.danger, weight: .semibold)
        case .expiringSoon(let daysLeft):
            badge(
                daysLeft == 0
                    ? L10n.text(L10n.Ingredients.freshnessExpiresToday)
                    : L10n.Ingredients.freshnessDaysLeft(daysLeft),
                color: AppTheme.warning,
                weight: .semibold
            )
        case .fresh:
            badge(L10n.text(L10n.Ingredients.freshnessFresh), color: .secondary, weight: .regular)
        case .noExpiry:
            badge(L10n.text(L10n.Ingredients.freshnessNoReminder), color: .secondary, weight: .regular)
        }
    }

    private func badge(_ text: String, color: Color, weight: Font.Weight) -> some View {
        Text(text)
            .font(.caption.weight(weight))
            .foregroundStyle(color)
    }
}

struct AppFloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppFloatingActionButtonLabel()
        }
        .accessibilityLabel(L10n.text(L10n.Ingredients.fabAddA11y))
    }
}

struct AppFloatingActionButtonLabel: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent, Color(red: 0.28, green: 0.52, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 14, x: 0, y: 8)
            .accessibilityLabel(L10n.text(L10n.Ingredients.fabAddA11y))
    }
}

struct IngredientStatusHeader: View {
    let ingredient: Ingredient

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(systemName: ingredient.location.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(ingredient.name)
                    .font(.title2.weight(.bold))

                HStack(spacing: 8) {
                    Text(ingredient.location.localizedTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    FreshnessBadge(freshness: ingredient.freshness)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private var tint: Color {
        switch ingredient.freshness {
        case .expired:
            return AppTheme.danger
        case .expiringSoon:
            return AppTheme.warning
        case .fresh, .noExpiry:
            return AppTheme.accent
        }
    }
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackground())
    }
}
