import SwiftUI
import WidgetKit

/// Medium widget view (4x2 grid)
/// Shows 3 recent notes in card layout with quick action button
struct MediumWidgetView: View {
    let entry: QuickCaptureTimelineProvider.Entry
    let colorScheme: ColorScheme

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Background gradient
            WidgetGradients.glassmorphic(colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header with quick action
                header

                Spacer(minLength: 4)

                // Content
                if entry.isAuthenticated {
                    if entry.captures.isEmpty {
                        // Empty state
                        emptyState
                    } else {
                        // Note cards
                        noteCards
                    }
                } else {
                    // Authentication required
                    authRequired
                }
            }
        }
        .id(entry.date)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: entry.date
        )
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            WidgetHeaderView(colorScheme: colorScheme, size: .medium, lastUpdated: entry.date)

            Spacer()

            // Quick action button
            Link(destination: URL(string: "durunotes://new-note")!) {
                QuickActionButton(colorScheme: colorScheme)
            }
            .padding(.trailing, 12)
        }
        .frame(height: 32)
    }

    // MARK: - Note Cards
    private var noteCards: some View {
        HStack(spacing: 8) {
            ForEach(Array(entry.captures.prefix(3))) { capture in
                Link(destination: URL(string: "durunotes://note/\(capture.id)")!) {
                    NoteCardView(capture: capture, colorScheme: colorScheme)
                }
            }

            // Add spacer if less than 3 notes
            if entry.captures.count < 3 {
                ForEach(0..<(3 - entry.captures.count), id: \.self) { _ in
                    placeholderCard
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.3),
            value: entry.captures.map { $0.id }
        )
    }

    // MARK: - Placeholder Card
    private var placeholderCard: some View {
        VStack {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(WidgetColors.textTertiary(colorScheme).opacity(0.3))
        }
        .frame(width: 94, height: 70)
        .background(WidgetColors.surfaceContainer(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    WidgetColors.surfaceBorder(colorScheme).opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView(
            colorScheme: colorScheme,
            message: "No captures yet",
            hint: "Tap + to create your first note",
            icon: "tray.fill",
            size: .medium
        )
    }

    // MARK: - Authentication Required
    private var authRequired: some View {
        VStack(spacing: 12) {
            EmptyStateView(
                colorScheme: colorScheme,
                message: "Sign in to view captures",
                hint: "Tap to open Duru Notes",
                icon: "lock.shield.fill",
                size: .medium
            )
        }
    }
}
