import SwiftUI
import WidgetKit

/// Small widget view (2x2 grid)
/// Shows most recent note with glassmorphic design
struct SmallWidgetView: View {
    let entry: QuickCaptureTimelineProvider.Entry
    let colorScheme: ColorScheme

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Background gradient
            WidgetGradients.glassmorphic(colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                WidgetHeaderView(colorScheme: colorScheme, size: .small, lastUpdated: entry.date)

                Spacer(minLength: 8)

                // Content
                if entry.isAuthenticated {
                    if let firstCapture = entry.captures.first {
                        // Show first note
                        noteContent(firstCapture)
                    } else {
                        // Empty state
                        emptyState
                    }
                } else {
                    // Authentication required
                    authRequired
                }

                // Footer accent strip
                Rectangle()
                    .fill(WidgetGradients.footerBar(colorScheme).opacity(0.8))
                    .frame(height: 4)
            }
        }
        .id(entry.date)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: entry.date
        )
    }

    // MARK: - Note Content
    @ViewBuilder
    private func noteContent(_ capture: QuickCaptureEntry.CaptureSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Note title
            Text(capture.title)
                .font(WidgetTypography.noteTitle(colorScheme, size: .small))
                .foregroundColor(WidgetColors.textPrimary(colorScheme))
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Note snippet
            if !capture.snippet.isEmpty {
                Text(capture.snippet)
                    .font(WidgetTypography.noteSnippet(colorScheme))
                    .foregroundColor(WidgetColors.textSecondary(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Timestamp
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(getTimestampText(for: capture))
            }
            .font(WidgetTypography.timestamp(colorScheme, size: .small))
            .foregroundColor(WidgetColors.textTertiary(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.3),
            value: capture.id
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView(
            colorScheme: colorScheme,
            message: "No captures yet",
            hint: "Tap to create",
            icon: "tray.fill",
            size: .small
        )
    }

    // MARK: - Authentication Required
    private var authRequired: some View {
        EmptyStateView(
            colorScheme: colorScheme,
            message: "Sign in required",
            hint: "Tap to authenticate",
            icon: "lock.shield.fill",
            size: .small
        )
    }

    // MARK: - Relative Time Helper
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Get timestamp text following the rule:
    /// - If updatedAt equals createdAt (within 1 second), show relative time from createdAt
    /// - Otherwise, show relative time from updatedAt
    private func getTimestampText(for capture: QuickCaptureEntry.CaptureSummary) -> String {
        let timeDiff = abs(capture.updatedAt.timeIntervalSince(capture.createdAt))

        // If timestamps are within 1 second of each other, treat as just created
        if timeDiff <= 1.0 {
            return relativeTime(from: capture.createdAt)
        } else {
            return relativeTime(from: capture.updatedAt)
        }
    }
}
