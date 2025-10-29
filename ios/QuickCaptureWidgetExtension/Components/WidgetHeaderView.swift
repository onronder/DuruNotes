import SwiftUI

/// Header component for QuickCapture widget
/// Shows app icon, title, and last updated timestamp
struct WidgetHeaderView: View {
    let colorScheme: ColorScheme
    let size: WidgetSize
    let lastUpdated: Date?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(WidgetColors.primary)

            Text("Quick Capture")
                .font(WidgetTypography.widgetTitle(colorScheme, size: size))
                .foregroundColor(WidgetColors.textPrimary(colorScheme))

            if let lastUpdated = lastUpdated {
                Text("(\(relativeTime(from: lastUpdated)))")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(WidgetColors.textTertiary(colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WidgetGradients.headerOverlay(colorScheme))
    }

    private var iconSize: CGFloat {
        size == .small ? 16 : 18
    }

    private func relativeTime(from date: Date) -> String {
        let secondsAgo = Date().timeIntervalSince(date)

        // Show "just now" for very recent updates (< 5 seconds)
        // This makes it clear the widget was just refreshed
        if secondsAgo < 5 {
            return "Updated just now"
        }

        // Use standard relative formatter for older updates
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relativeString = formatter.localizedString(for: date, relativeTo: Date())

        // Prefix with "Updated" to clarify this is widget refresh time
        return "Updated \(relativeString)"
    }
}
