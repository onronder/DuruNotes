import WidgetKit
import SwiftUI

struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> ()) {
        let entry = QuickCaptureEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = QuickCaptureEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
}

struct QuickCaptureWidgetEntryView : View {
    var entry: QuickCaptureProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.6, blue: 0.9),
                    Color(red: 0.1, green: 0.4, blue: 0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                // App icon and title
                HStack {
                    Image(systemName: "note.text.badge.plus")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Quick Capture")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                
                // Action buttons based on widget size
                if family == .systemSmall {
                    // Small widget - single tap action
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Tap to add note")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                } else if family == .systemMedium {
                    // Medium widget - two actions
                    HStack(spacing: 20) {
                        ActionButton(
                            icon: "note.text",
                            title: "Text Note",
                            url: "durunotes://quick-capture/text"
                        )
                        ActionButton(
                            icon: "mic.fill",
                            title: "Voice Note",
                            url: "durunotes://quick-capture/voice"
                        )
                    }
                } else {
                    // Large widget - multiple actions
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ActionButton(
                                icon: "note.text",
                                title: "Text Note",
                                url: "durunotes://quick-capture/text"
                            )
                            ActionButton(
                                icon: "mic.fill",
                                title: "Voice Note",
                                url: "durunotes://quick-capture/voice"
                            )
                        }
                        HStack(spacing: 16) {
                            ActionButton(
                                icon: "camera.fill",
                                title: "Photo Note",
                                url: "durunotes://quick-capture/photo"
                            )
                            ActionButton(
                                icon: "checklist",
                                title: "Task List",
                                url: "durunotes://quick-capture/task"
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .widgetURL(URL(string: "durunotes://quick-capture"))
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
        }
    }
}

@main
struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Quickly capture notes, voice memos, and tasks")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct QuickCaptureWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuickCaptureWidgetEntryView(entry: QuickCaptureEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            QuickCaptureWidgetEntryView(entry: QuickCaptureEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            QuickCaptureWidgetEntryView(entry: QuickCaptureEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}