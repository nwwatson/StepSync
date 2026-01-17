import WidgetKit
import SwiftUI

struct StartWalkEntry: TimelineEntry {
    let date: Date
}

struct StartWalkProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartWalkEntry {
        StartWalkEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StartWalkEntry) -> Void) {
        completion(StartWalkEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartWalkEntry>) -> Void) {
        let entry = StartWalkEntry(date: Date())
        // Static complication, update once per day
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct StartWalkComplication: Widget {
    let kind: String = "StartWalkComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StartWalkProvider()) { entry in
            StartWalkComplicationView(entry: entry)
        }
        .configurationDisplayName("Start Walk")
        .description("Quickly start a walking workout.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct StartWalkComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: StartWalkEntry

    /// Deep link URL to start a walking workout
    private let deepLinkURL = URL(string: "stepsync://workout/start?type=walking")!

    var body: some View {
        Group {
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
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(deepLinkURL)
    }

    private var circularView: some View {
        VStack(spacing: 2) {
            Image(systemName: "figure.walk")
                .font(.title3)
                .foregroundStyle(.green)

            Text("Walk")
                .font(.system(size: 10, weight: .medium))
        }
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Start Walk")
                    .font(.headline)

                Text("Tap to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.walk")
            Text("Start Walk")
        }
    }

    private var cornerView: some View {
        Image(systemName: "figure.walk")
            .font(.title3)
            .foregroundStyle(.green)
            .widgetLabel {
                Text("Walk")
            }
    }
}

#Preview(as: .accessoryCircular) {
    StartWalkComplication()
} timeline: {
    StartWalkEntry(date: Date())
}

#Preview(as: .accessoryRectangular) {
    StartWalkComplication()
} timeline: {
    StartWalkEntry(date: Date())
}
