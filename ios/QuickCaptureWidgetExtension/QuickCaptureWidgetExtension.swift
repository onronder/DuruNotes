import WidgetKit
import SwiftUI

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
    let captures: [CaptureSummary]
    let isAuthenticated: Bool

    struct CaptureSummary: Identifiable {
        let id: String
        let title: String
        let snippet: String
        let createdAt: Date
        let updatedAt: Date
    }
}

struct QuickCaptureTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(
            date: Date(),
            captures: [
                .init(
                    id: "placeholder",
                    title: "Quick capture",
                    snippet: "Tap to open",
                    createdAt: Date(),
                    updatedAt: Date()
                ),
            ],
            isAuthenticated: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        let payload = QuickCaptureWidgetSharedStore().readPayload()
        let captures = Self.parseCaptures(from: payload)
        let isAuthenticated = (payload?["userId"] as? String)?.isEmpty == false

        // Use current time for entry date so relative timestamps update with each widget refresh
        let entry = QuickCaptureEntry(
            date: Date(),
            captures: captures,
            isAuthenticated: isAuthenticated
        )

        // Refresh every 15 seconds to keep timestamp current
        let nextUpdate = Date().addingTimeInterval(15)
        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextUpdate)
            )
        )
    }

    private static func parseCaptures(from payload: [String: Any]?) -> [QuickCaptureEntry.CaptureSummary] {
        guard let captures = payload?["recentCaptures"] as? [[String: Any]] else {
            return []
        }

        // Primary formatter with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Fallback formatter without fractional seconds (more lenient)
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        return captures.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let title = (item["title"] as? String) ?? "Quick capture"
            let snippet = (item["snippet"] as? String) ?? ""

            // Parse createdAt with fallback
            let createdAtIso = item["createdAt"] as? String
            let createdAt: Date
            if let isoString = createdAtIso,
               let parsed = formatter.date(from: isoString) ?? fallbackFormatter.date(from: isoString) {
                createdAt = parsed
            } else {
                // Use distant past for unparseable dates to show actual age
                createdAt = Date.distantPast
                print("⚠️ Failed to parse createdAt: \(createdAtIso ?? "nil")")
            }

            // Parse updatedAt with fallback
            let updatedAtIso = item["updatedAt"] as? String
            let updatedAt: Date
            if let isoString = updatedAtIso,
               let parsed = formatter.date(from: isoString) ?? fallbackFormatter.date(from: isoString) {
                updatedAt = parsed
            } else {
                // Use distant past for unparseable dates
                updatedAt = Date.distantPast
                print("⚠️ Failed to parse updatedAt: \(updatedAtIso ?? "nil")")
            }

            return QuickCaptureEntry.CaptureSummary(
                id: id,
                title: title,
                snippet: snippet,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private static func parseUpdatedAt(from payload: [String: Any]?) -> Date? {
        guard let updatedAtIso = payload?["updatedAt"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: updatedAtIso)
    }
}

struct QuickCaptureWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var colorScheme

    var entry: QuickCaptureTimelineProvider.Entry

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                SmallWidgetView(entry: entry, colorScheme: colorScheme)
            case .systemMedium:
                MediumWidgetView(entry: entry, colorScheme: colorScheme)
            default:
                // Fallback for unsupported sizes
                Text("Unsupported widget size")
            }
        }
        .widgetBackground()
    }
}

// MARK: - iOS 17+ Background Support
extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self
        }
    }
}

struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureTimelineProvider()) { entry in
            QuickCaptureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Capture ideas and view recent notes at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
