import SwiftUI
import WidgetKit

/// Individual note card component for medium widget
/// Shows note title, icon, and relative timestamp
struct NoteCardView: View {
    let capture: QuickCaptureEntry.CaptureSummary
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category icon
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(WidgetColors.primary)

            Spacer()
                .frame(height: 4)

            // Title
            Text(capture.title)
                .font(WidgetTypography.noteTitle(colorScheme, size: .medium))
                .foregroundColor(WidgetColors.textPrimary(colorScheme))
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Timestamp
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                Text(getTimestampText())
            }
            .font(WidgetTypography.timestamp(colorScheme, size: .medium))
            .foregroundColor(WidgetColors.textTertiary(colorScheme))
        }
        .padding(10)
        .frame(width: 94, height: 70)
        .background(WidgetGradients.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    WidgetColors.surfaceBorder(colorScheme),
                    lineWidth: 1
                )
        )
        .shadow(
            color: WidgetColors.shadowColor(colorScheme),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    /// Convert date to relative time string (e.g., "5m ago", "2h ago")
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Get timestamp text following the rule:
    /// - If updatedAt equals createdAt (within 1 second), show relative time from createdAt
    /// - Otherwise, show relative time from updatedAt
    private func getTimestampText() -> String {
        let timeDiff = abs(capture.updatedAt.timeIntervalSince(capture.createdAt))

        // If timestamps are within 1 second of each other, treat as just created
        if timeDiff <= 1.0 {
            return relativeTime(from: capture.createdAt)
        } else {
            return relativeTime(from: capture.updatedAt)
        }
    }
}
