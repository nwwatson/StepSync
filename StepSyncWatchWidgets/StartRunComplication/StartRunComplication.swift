import WidgetKit
import SwiftUI

struct StartRunEntry: TimelineEntry {
    let date: Date
}

struct StartRunProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartRunEntry {
        StartRunEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StartRunEntry) -> Void) {
        completion(StartRunEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartRunEntry>) -> Void) {
        let entry = StartRunEntry(date: Date())
        // Static complication, update once per day
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct StartRunComplication: Widget {
    let kind: String = "StartRunComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StartRunProvider()) { entry in
            StartRunComplicationView(entry: entry)
        }
        .configurationDisplayName("Start Run")
        .description("Quickly start a running workout.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct StartRunComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: StartRunEntry

    /// Deep link URL to start a running workout
    private let deepLinkURL = URL(string: "stepsync://workout/start?type=running")!

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
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundStyle(.orange)

            Text("Run")
                .font(.system(size: 10, weight: .medium))
        }
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Start Run")
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
            Image(systemName: "figure.run")
            Text("Start Run")
        }
    }

    private var cornerView: some View {
        Image(systemName: "figure.run")
            .font(.title3)
            .foregroundStyle(.orange)
            .widgetLabel {
                Text("Run")
            }
    }
}

#Preview(as: .accessoryCircular) {
    StartRunComplication()
} timeline: {
    StartRunEntry(date: Date())
}

#Preview(as: .accessoryRectangular) {
    StartRunComplication()
} timeline: {
    StartRunEntry(date: Date())
}
