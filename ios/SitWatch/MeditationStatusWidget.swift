import SwiftUI
import WidgetKit

// MARK: - Shared Storage

/// Shared UserDefaults key for last meditation date
/// Using standard UserDefaults since Watch app and Widget extension share the same container
enum MeditationStorage {
    static let lastMeditationDateKey = "lastMeditationDate"

    static func didMeditateToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastMeditationDateKey) as? Date else {
            return false
        }

        return Calendar.current.isDateInToday(lastDate)
    }

    static func recordMeditation() {
        UserDefaults.standard.set(Date(), forKey: lastMeditationDateKey)
    }
}

// MARK: - Widget Timeline Entry

struct MeditationStatusEntry: TimelineEntry {
    let date: Date
    let didMeditateToday: Bool
}

// MARK: - Widget Provider

struct MeditationStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeditationStatusEntry {
        MeditationStatusEntry(date: Date(), didMeditateToday: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (MeditationStatusEntry) -> Void) {
        let entry = MeditationStatusEntry(
            date: Date(),
            didMeditateToday: MeditationStorage.didMeditateToday()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeditationStatusEntry>) -> Void) {
        let currentDate = Date()
        let didMeditate = MeditationStorage.didMeditateToday()

        // Create entry for now
        let entry = MeditationStatusEntry(
            date: currentDate,
            didMeditateToday: didMeditate
        )

        // Schedule next update at midnight (start of next day)
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)

        // Create timeline with current entry and update policy at midnight
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct MeditationStatusWidgetView: View {
    let entry: MeditationStatusEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    // Circular complication - just an icon
    private var circularView: some View {
        Image(systemName: entry.didMeditateToday ? "checkmark.circle.fill" : "circle")
            .font(.title)
            .widgetAccentable()
    }

    // Rectangular complication
    private var rectangularView: some View {
        HStack {
            Image(systemName: entry.didMeditateToday ? "checkmark.circle.fill" : "circle")
                .widgetAccentable()
            VStack(alignment: .leading) {
                Text("Sit")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.didMeditateToday ? "Done" : "Not yet")
                    .font(.caption)
            }
        }
    }

    // Inline complication (text only)
    private var inlineView: some View {
        Label(entry.didMeditateToday ? "Done" : "Sit", systemImage: entry.didMeditateToday ? "checkmark.circle" : "circle")
    }

    // Corner complication
    private var cornerView: some View {
        Image(systemName: entry.didMeditateToday ? "checkmark.circle.fill" : "circle")
            .widgetAccentable()
    }
}

// MARK: - Widget Configuration

@main
struct MeditationStatusWidget: Widget {
    let kind: String = "MeditationStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeditationStatusProvider()) { entry in
            MeditationStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Sit")
        .description("Open the Sit app")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    MeditationStatusWidget()
} timeline: {
    MeditationStatusEntry(date: Date(), didMeditateToday: true)
    MeditationStatusEntry(date: Date(), didMeditateToday: false)
}
