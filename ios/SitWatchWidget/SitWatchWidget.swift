import WidgetKit
import SwiftUI

struct SitEntry: TimelineEntry {
    let date: Date
}

struct SitProvider: TimelineProvider {
    func placeholder(in context: Context) -> SitEntry {
        SitEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SitEntry) -> ()) {
        completion(SitEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SitEntry>) -> ()) {
        let timeline = Timeline(entries: [SitEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct SitWidgetView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "figure.mind.and.body")
                .font(.largeTitle)
                .widgetAccentable()
        case .accessoryRectangular:
            HStack {
                Image(systemName: "figure.mind.and.body")
                    .font(.title)
                    .widgetAccentable()
                Text("Sit")
                    .font(.headline)
            }
        case .accessoryInline:
            Label("Sit", systemImage: "figure.mind.and.body")
        case .accessoryCorner:
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 24))
                .fontWeight(.medium)
                .widgetAccentable()
        default:
            Image(systemName: "figure.mind.and.body")
                .font(.title)
        }
    }
}

struct SitWatchWidget: Widget {
    let kind: String = "SitWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SitProvider()) { _ in
            SitWidgetView()
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

#Preview(as: .accessoryCircular) {
    SitWatchWidget()
} timeline: {
    SitEntry(date: .now)
}
