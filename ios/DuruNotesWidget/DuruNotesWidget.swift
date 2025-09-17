import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget View
struct DuruNotesWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.2, blue: 0.4), Color(red: 0.2, green: 0.3, blue: 0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                // App icon and title
                HStack {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Duru Notes")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                
                // Action buttons based on widget size
                switch family {
                case .systemSmall:
                    // Small widget - single tap to create note
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Quick Note")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                case .systemMedium:
                    // Medium widget - text and voice buttons
                    HStack(spacing: 20) {
                        ActionButton(
                            icon: "note.text",
                            title: "Text Note",
                            url: "durunotes://create?type=text"
                        )
                        ActionButton(
                            icon: "mic.fill",
                            title: "Voice Note",
                            url: "durunotes://create?type=voice"
                        )
                    }
                    
                case .systemLarge:
                    // Large widget - all options
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ActionButton(
                                icon: "note.text",
                                title: "Text Note",
                                url: "durunotes://create?type=text"
                            )
                            ActionButton(
                                icon: "mic.fill",
                                title: "Voice Note",
                                url: "durunotes://create?type=voice"
                            )
                        }
                        HStack(spacing: 16) {
                            ActionButton(
                                icon: "camera.fill",
                                title: "Photo Note",
                                url: "durunotes://create?type=photo"
                            )
                            ActionButton(
                                icon: "checklist",
                                title: "Task List",
                                url: "durunotes://create?type=task"
                            )
                        }
                    }
                    
                default:
                    EmptyView()
                }
                
                if family != .systemSmall {
                    Spacer()
                }
            }
            .padding()
        }
        .widgetURL(URL(string: family == .systemSmall ? "durunotes://create?type=text" : "durunotes://home"))
    }
}

// MARK: - Action Button Component
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

// MARK: - Widget Configuration
struct DuruNotesWidget: Widget {
    let kind: String = "DuruNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DuruNotesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Create notes quickly from your home screen")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
struct DuruNotesWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DuruNotesWidgetEntryView(entry: SimpleEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            DuruNotesWidgetEntryView(entry: SimpleEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            DuruNotesWidgetEntryView(entry: SimpleEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
