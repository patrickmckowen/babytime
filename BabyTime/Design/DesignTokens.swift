//
//  DesignTokens.swift
//  BabyTime
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Typography Scale

enum BTTypography {
    /// Primary metric - the dominant time display (56pt semibold rounded)
    static let displayLarge: Font = .system(size: 56, weight: .semibold, design: .rounded)

    /// Section label - "Next nap" (15pt medium)
    static let label: Font = .system(size: 15, weight: .medium, design: .default)

    /// Supporting context - "Wake window" (13pt regular)
    static let caption: Font = .system(size: 13, weight: .regular, design: .default)

    /// CTA button text (17pt medium)
    static let button: Font = .system(size: 17, weight: .medium, design: .default)
}

// MARK: - Semantic Colors

enum BTColors {
    // Text hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    #if canImport(UIKit)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    #else
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    #endif

    // Interactive elements
    static let actionPrimary = Color.accentColor
    static let actionPrimarySubtle = Color.accentColor.opacity(0.12)

    // Surfaces
    #if canImport(UIKit)
    static let surfaceCard = Color(uiColor: .secondarySystemBackground)
    static let surfacePage = Color(uiColor: .systemBackground)
    #else
    static let surfaceCard = Color(nsColor: .windowBackgroundColor)
    static let surfacePage = Color(nsColor: .windowBackgroundColor)
    #endif

    // Card styling
    static let cardShadow = Color.black.opacity(0.06)
    #if canImport(UIKit)
    static let cardBorder = Color(uiColor: .separator).opacity(0.5)
    #else
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.5)
    #endif
}

// MARK: - Spacing Scale (8pt grid)

enum BTSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radii

enum BTRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 20
}

// MARK: - Shadows

enum BTShadow {
    static let card = ShadowStyle(
        color: BTColors.cardShadow,
        radius: 12,
        x: 0,
        y: 4
    )

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}
