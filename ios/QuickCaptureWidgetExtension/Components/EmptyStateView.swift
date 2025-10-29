import SwiftUI

/// Empty state component for widget
/// Shows friendly message when no notes or authentication required
struct EmptyStateView: View {
    let colorScheme: ColorScheme
    let message: String
    let hint: String
    let icon: String
    let size: WidgetSize

    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(spacing: size == .small ? 8 : 12) {
            // Icon with subtle shimmer animation
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .light))
                .foregroundColor(WidgetColors.textTertiary(colorScheme).opacity(0.4))
                .overlay(
                    Rectangle()
                        .fill(WidgetGradients.shimmer)
                        .offset(x: shimmerOffset)
                        .mask(
                            Image(systemName: icon)
                                .font(.system(size: iconSize, weight: .light))
                        )
                )
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        shimmerOffset = 200
                    }
                }

            VStack(spacing: 4) {
                // Title
                Text(message)
                    .font(WidgetTypography.emptyStateTitle(colorScheme))
                    .foregroundColor(WidgetColors.textPrimary(colorScheme))

                // Hint
                Text(hint)
                    .font(WidgetTypography.emptyStateBody(colorScheme))
                    .foregroundColor(WidgetColors.textTertiary(colorScheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconSize: CGFloat {
        size == .small ? 32 : 40
    }
}
