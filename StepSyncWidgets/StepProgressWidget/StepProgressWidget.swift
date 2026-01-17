import WidgetKit
import SwiftUI

struct StepProgressEntry: TimelineEntry {
    let date: Date
    let stepCount: Int
    let goalTarget: Int
    let streakCount: Int

    var progressPercentage: Double {
        guard goalTarget > 0 else { return 0 }
        return min(Double(stepCount) / Double(goalTarget), 1.0)
    }

    var isGoalAchieved: Bool {
        stepCount >= goalTarget
    }
}

struct StepProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepProgressEntry {
        StepProgressEntry(date: Date(), stepCount: 7500, goalTarget: 10000, streakCount: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepProgressEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepProgressEntry>) -> Void) {
        let entry = loadEntry()

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> StepProgressEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")

        let stepCount = userDefaults?.integer(forKey: "todayStepCount") ?? 0
        let goalTarget = userDefaults?.integer(forKey: "dailyGoal") ?? 10000
        let streakCount = userDefaults?.integer(forKey: "currentStreak") ?? 0

        return StepProgressEntry(
            date: Date(),
            stepCount: stepCount,
            goalTarget: goalTarget,
            streakCount: streakCount
        )
    }
}

struct StepProgressWidget: Widget {
    let kind: String = "StepProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepProgressProvider()) { entry in
            StepProgressWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Step Progress")
        .description("Track your daily step progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct StepProgressWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: StepProgressEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .accessoryCircular:
            circularWidget
        case .accessoryRectangular:
            rectangularWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.progressPercentage)
                    .stroke(
                        entry.isGoalAchieved ? Color.green : Color.primary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(formatSteps(entry.stepCount))
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("steps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            if entry.streakCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(entry.streakCount)")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
            }
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: entry.progressPercentage)
                    .stroke(
                        entry.isGoalAchieved ? Color.green : Color.primary,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(formatSteps(entry.stepCount))
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("of \(formatSteps(entry.goalTarget))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 8) {
                if entry.isGoalAchieved {
                    Label("Goal achieved!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Text("\(formatSteps(entry.goalTarget - entry.stepCount)) to go")
                        .font(.headline)
                }

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(entry.streakCount) day streak")
                        .font(.subheadline)
                }

                Text("\(Int(entry.progressPercentage * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()

            Gauge(value: entry.progressPercentage) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Text("\(Int(entry.progressPercentage * 100))")
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
        }
    }

    private var rectangularWidget: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(formatSteps(entry.stepCount))
                    .font(.headline)

                Text("of \(formatSteps(entry.goalTarget))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Gauge(value: entry.progressPercentage) {
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .frame(width: 60)
        }
    }

    private func formatSteps(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return count.formatted()
    }
}

#Preview(as: .systemSmall) {
    StepProgressWidget()
} timeline: {
    StepProgressEntry(date: Date(), stepCount: 7500, goalTarget: 10000, streakCount: 5)
    StepProgressEntry(date: Date(), stepCount: 10500, goalTarget: 10000, streakCount: 6)
}
