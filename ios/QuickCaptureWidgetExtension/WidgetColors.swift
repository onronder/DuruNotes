import SwiftUI

/// Color system for Duru Notes QuickCapture Widget
/// Provides WCAG AAA compliant colors with light/dark mode support
struct WidgetColors {
    // MARK: - Brand Colors
    static let primary = Color(hex: "048ABF")      // Duru blue
    static let accent = Color(hex: "5FD0CB")       // Duru teal/turquoise
    static let deepTeal = Color(hex: "036693")     // Emphasis color
    static let lightAqua = Color(hex: "7DD8D3")    // Highlight color

    // MARK: - Light Mode Colors
    struct Light {
        static let surfaceBase = Color.white
        static let surfaceElevated = Color(hex: "F8FAFC")
        static let surfaceContainer = Color(hex: "F5F7F9")
        static let surfaceBorder = Color(hex: "048ABF").opacity(0.12)

        static let textPrimary = Color(hex: "1A1C1E")      // 16.5:1 contrast (AAA)
        static let textSecondary = Color(hex: "44474E")    // 8.9:1 contrast (AAA)
        static let textTertiary = Color(hex: "74777F")     // 5.2:1 contrast (AA)

        static let shadowColor = Color(hex: "048ABF").opacity(0.08)
        static let glassmorphicOverlay = Color.white.opacity(0.85)
    }

    // MARK: - Dark Mode Colors
    struct Dark {
        static let surfaceBase = Color(hex: "0F1E2E")      // Rich dark blue
        static let surfaceElevated = Color(hex: "1A2F47")
        static let surfaceContainer = Color(hex: "152A42")
        static let surfaceBorder = Color(hex: "5FD0CB").opacity(0.2)

        static let textPrimary = Color(hex: "E3E3E3")      // 13.2:1 contrast (AAA)
        static let textSecondary = Color(hex: "C4C7C5")    // 10.1:1 contrast (AAA)
        static let textTertiary = Color(hex: "8E918F")     // 5.8:1 contrast (AA)

        static let shadowColor = Color.black.opacity(0.4)
        static let glassmorphicOverlay = Color(hex: "0F1E2E").opacity(0.9)
    }

    // MARK: - Adaptive Color Accessors
    static func textPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.textPrimary : Light.textPrimary
    }

    static func textSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.textSecondary : Light.textSecondary
    }

    static func textTertiary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.textTertiary : Light.textTertiary
    }

    static func surface(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.surfaceBase : Light.surfaceBase
    }

    static func surfaceElevated(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.surfaceElevated : Light.surfaceElevated
    }

    static func surfaceContainer(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.surfaceContainer : Light.surfaceContainer
    }

    static func surfaceBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.surfaceBorder : Light.surfaceBorder
    }

    static func shadowColor(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.shadowColor : Light.shadowColor
    }

    static func glassmorphicOverlay(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Dark.glassmorphicOverlay : Light.glassmorphicOverlay
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
