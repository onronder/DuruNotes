import SwiftUI

/// Gradient system for Duru Notes QuickCapture Widget
/// Provides branded gradients and glassmorphic overlays
struct WidgetGradients {
    // MARK: - Logo Gradient (Primary Brand Gradient)
    static let logo = LinearGradient(
        colors: [WidgetColors.primary, WidgetColors.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Header Overlay (Subtle Background Accent)
    static func headerOverlay(_ colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    WidgetColors.accent.opacity(0.03),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    WidgetColors.accent.opacity(0.05),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    // MARK: - Glassmorphic Background
    static func glassmorphic(_ colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(hex: "0F1E2E").opacity(0.9),
                    WidgetColors.primary.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.85),
                    WidgetColors.accent.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Footer Bar (Accent Strip)
    static func footerBar(_ colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [WidgetColors.primary, WidgetColors.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Card Gradient (Subtle Elevation Effect)
    static func cardBackground(_ colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    WidgetColors.Dark.surfaceElevated,
                    WidgetColors.Dark.surfaceContainer
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    WidgetColors.Light.surfaceElevated,
                    WidgetColors.Light.surfaceBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Badge Background
    static let badgeBackground = LinearGradient(
        colors: [
            WidgetColors.accent.opacity(0.15),
            WidgetColors.accent.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Quick Action Button Gradient
    static func quickActionGradient(_ colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                WidgetColors.primary.opacity(0.9),
                WidgetColors.accent.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shimmer Effect (for empty states)
    static let shimmer = LinearGradient(
        colors: [
            Color.clear,
            WidgetColors.accent.opacity(0.3),
            Color.clear
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
