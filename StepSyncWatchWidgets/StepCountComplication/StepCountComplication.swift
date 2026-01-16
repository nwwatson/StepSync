import WidgetKit
import SwiftUI

struct StepCountEntry: TimelineEntry {
    let date: Date
    let stepCount: Int
    let goalTarget: Int

    var progressPercentage: Double {
        guard goalTarget > 0 else { return 0 }
        return min(Double(stepCount) / Double(goalTarget), 1.0)
    }

    var isGoalAchieved: Bool {
        stepCount >= goalTarget
    }
}

struct StepCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepCountEntry {
        StepCountEntry(date: Date(), stepCount: 7500, goalTarget: 10000)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepCountEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepCountEntry>) -> Void) {
        let entry = loadEntry()

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> StepCountEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.stepsync")

        let stepCount = userDefaults?.integer(forKey: "todayStepCount") ?? 0
        let goalTarget = userDefaults?.integer(forKey: "dailyGoal") ?? 10000

        return StepCountEntry(
            date: Date(),
            stepCount: stepCount,
            goalTarget: goalTarget
        )
    }
}

struct StepCountComplication: Widget {
    let kind: String = "StepCountComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepCountProvider()) { entry in
            StepCountComplicationView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Shows your current step count.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct StepCountComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: StepCountEntry

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

    private var circularView: some View {
        Gauge(value: entry.progressPercentage) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(formatStepsShort(entry.stepCount))
                .font(.system(size: 12, weight: .medium))
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)

                    Text(formatSteps(entry.stepCount))
                        .font(.headline)
                }

                Text("of \(formatSteps(entry.goalTarget))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Gauge(value: entry.progressPercentage) {
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .frame(width: 40)
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.walk")
            Text("\(formatSteps(entry.stepCount)) steps")
        }
    }

    private var cornerView: some View {
        ZStack {
            AccessoryWidgetBackground()

            Gauge(value: entry.progressPercentage) {
                Image(systemName: "figure.walk")
            }
            .gaugeStyle(.accessoryCircular)
        }
    }

    private func formatSteps(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return count.formatted()
    }

    private func formatStepsShort(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

#Preview(as: .accessoryCircular) {
    StepCountComplication()
} timeline: {
    StepCountEntry(date: Date(), stepCount: 7500, goalTarget: 10000)
}
