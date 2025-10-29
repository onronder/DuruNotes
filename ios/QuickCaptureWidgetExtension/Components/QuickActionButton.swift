import SwiftUI

/// Quick action button for creating new notes
/// Appears in medium widget header with gradient background
struct QuickActionButton: View {
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Gradient background
            WidgetGradients.quickActionGradient(colorScheme)
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            // Plus icon
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .shadow(
            color: WidgetColors.shadowColor(colorScheme),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}
