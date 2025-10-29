import SwiftUI

/// Typography system for Duru Notes QuickCapture Widget
/// Defines SF Pro font hierarchy with dynamic type scaling
struct WidgetTypography {
    // MARK: - Widget Title (Header)
    static func widgetTitle(_ colorScheme: ColorScheme, size: WidgetSize) -> Font {
        let baseSize: CGFloat = size == .small ? 12 : 14
        return .system(size: baseSize, weight: .semibold, design: .rounded)
    }

    // MARK: - Note Title (Primary Content)
    static func noteTitle(_ colorScheme: ColorScheme, size: WidgetSize) -> Font {
        let baseSize: CGFloat = size == .small ? 15 : 14
        return .system(size: baseSize, weight: .semibold, design: .default)
    }

    // MARK: - Note Snippet (Secondary Content)
    static func noteSnippet(_ colorScheme: ColorScheme) -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    // MARK: - Timestamp
    static func timestamp(_ colorScheme: ColorScheme, size: WidgetSize) -> Font {
        let baseSize: CGFloat = size == .small ? 11 : 10
        return .system(size: baseSize, weight: .regular, design: .default)
    }

    // MARK: - Badge Text
    static func badge(_ colorScheme: ColorScheme) -> Font {
        .system(size: 11, weight: .medium, design: .rounded)
    }

    // MARK: - Empty State Title
    static func emptyStateTitle(_ colorScheme: ColorScheme) -> Font {
        .system(size: 14, weight: .semibold, design: .default)
    }

    // MARK: - Empty State Body
    static func emptyStateBody(_ colorScheme: ColorScheme) -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    // MARK: - Footer Text
    static func footerText(_ colorScheme: ColorScheme) -> Font {
        .system(size: 10, weight: .regular, design: .default)
    }
}

/// Widget size enumeration for typography scaling
enum WidgetSize {
    case small
    case medium
}
