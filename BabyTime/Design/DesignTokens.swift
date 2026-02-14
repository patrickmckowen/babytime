//
//  DesignTokens.swift
//  BabyTime
//
//  Semantic design tokens for the warm, minimal BabyTime palette.
//

import SwiftUI

// MARK: - Color Tokens

extension Color {
    /// Page background and card background (cards float via shadow)
    static let btBackground = Color(red: 0.961, green: 0.945, blue: 0.922) // #F5F1EB

    /// Headlines, stat values, primary content
    static let btTextPrimary = Color(red: 0.173, green: 0.145, blue: 0.125) // #2C2520

    /// Labels, subheads, supporting text
    static let btTextSecondary = Color(red: 0.608, green: 0.557, blue: 0.510) // #9B8E82

    /// Stat column labels in the Today card
    static let btTextMuted = Color(red: 0.741, green: 0.694, blue: 0.647) // #BDB1A5

    /// Sleep icon and icon container tint
    static let btSleepAccent = Color(red: 0.482, green: 0.655, blue: 0.761) // #7BA7C2

    /// Feed icon and icon container tint
    static let btFeedAccent = Color(red: 0.784, green: 0.569, blue: 0.420) // #C8916B

    /// Hairline divider in Today card
    static let btDivider = Color(red: 0.173, green: 0.145, blue: 0.125).opacity(0.06) // #2C2520 @ 6%

    /// Empty state for baby photo
    static let btPhotoPlaceholder = Color(red: 0.910, green: 0.878, blue: 0.839) // #E8E0D6
}

// MARK: - Typography

enum BTTypography {
    /// Card primary values — "3:30 PM", "1h 25m" (44pt bold, -2.2 tracking)
    static let headline: Font = .system(size: 44, weight: .bold)

    /// Text-based card headlines — "Ready when you are" (28pt bold, -1.2 tracking)
    static let headlineSmall: Font = .system(size: 28, weight: .bold)

    /// Card labels, subheads, supporting text (17pt medium, -0.2 tracking)
    static let label: Font = .system(size: 17, weight: .medium)

    /// Date line on photo overlay (17pt semibold, -0.3 tracking)
    static let photoDate: Font = .system(size: 17, weight: .semibold)

    /// Age line on photo overlay (17pt semibold, -0.3 tracking)
    static let photoAge: Font = .system(size: 17, weight: .semibold)

    /// Values in Today card stat rows (17pt semibold, -0.4 tracking)
    static let statValue: Font = .system(size: 17, weight: .semibold)

    /// Labels above stat values in Today card (13pt medium, -0.1 tracking)
    static let statLabel: Font = .system(size: 13, weight: .medium)

    /// Supporting context — timeline details (13pt regular)
    static let caption: Font = .system(size: 13, weight: .regular)
}

// MARK: - Tracking (letter-spacing)

enum BTTracking {
    static let headline: CGFloat = -2.2
    static let headlineSmall: CGFloat = -1.2
    static let label: CGFloat = -0.2
    static let photoDate: CGFloat = -0.3
    static let photoAge: CGFloat = -0.3
    static let statValue: CGFloat = -0.4
    static let statLabel: CGFloat = -0.1
}

// MARK: - Spacing

enum BTSpacing {
    /// Horizontal page margins
    static let pageMargin: CGFloat = 24

    /// Photo bottom to first card
    static let photoToCard: CGFloat = 20

    /// Card to card
    static let cardGap: CGFloat = 14

    /// Card label to headline
    static let labelToHeadline: CGFloat = 6

    /// Card headline to detail line
    static let headlineToDetail: CGFloat = 12

    /// Today header to first row
    static let todayHeaderToRow: CGFloat = 22

    /// Row to divider and divider to row
    static let rowDividerPadding: CGFloat = 18

    /// Icon container to first stat column
    static let iconToStat: CGFloat = 14

    /// Card internal padding
    static let cardPaddingTop: CGFloat = 26
    static let cardPaddingHorizontal: CGFloat = 24
    static let cardPaddingBottom: CGFloat = 24
}

// MARK: - Radii

enum BTRadius {
    static let card: CGFloat = 22
    static let iconContainer: CGFloat = 10
}

// MARK: - Icon Sizes

enum BTIconSize {
    static let container: CGFloat = 36
}
