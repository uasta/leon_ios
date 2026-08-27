import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.18, green: 0.42, blue: 1.0)
    static let accentSoft = Color(red: 0.18, green: 0.42, blue: 1.0).opacity(0.12)

    static let warning = Color(red: 0.90, green: 0.60, blue: 0.09)
    static let warningBackground = Color(red: 1.0, green: 0.97, blue: 0.92)

    static let danger = Color(red: 0.88, green: 0.33, blue: 0.33)
    static let dangerBackground = Color(red: 1.0, green: 0.95, blue: 0.95)

    static let mutedText = Color.secondary
    static let sectionLabel = Color(red: 0.48, green: 0.53, blue: 0.60)

    static let cardRadius: CGFloat = 16
    static let pillRadius: CGFloat = 999

    static func screenBackground(in scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color(red: 0.10, green: 0.12, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 0.99),
                Color(red: 0.93, green: 0.95, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum InventorySectionKind {
        case expiring
        case expired
        case standard
    }

    static func sectionBackground(for kind: InventorySectionKind, scheme: ColorScheme) -> Color {
        switch kind {
        case .expiring:
            return scheme == .dark
                ? Color.orange.opacity(0.14)
                : warningBackground
        case .expired:
            return scheme == .dark
                ? Color.red.opacity(0.12)
                : dangerBackground
        case .standard:
            return Color(.secondarySystemGroupedBackground)
        }
    }

    static func sectionLabelColor(for kind: InventorySectionKind) -> Color {
        switch kind {
        case .expiring:
            return warning
        case .expired:
            return Color(red: 0.79, green: 0.42, blue: 0.13)
        case .standard:
            return sectionLabel
        }
    }
}
