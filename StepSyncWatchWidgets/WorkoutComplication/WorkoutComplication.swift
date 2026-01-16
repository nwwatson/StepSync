import WidgetKit
import SwiftUI

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let isWorkoutActive: Bool
    let workoutType: String
    let elapsedTime: TimeInterval
}

struct WorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: Date(), isWorkoutActive: false, workoutType: "walking", elapsedTime: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let entry = loadEntry()

        let nextUpdate: Date
        if entry.isWorkoutActive {
            nextUpdate = Date().addingTimeInterval(60)
        } else {
            nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        }

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> WorkoutEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.stepsync")

        let isActive = userDefaults?.bool(forKey: "isWorkoutActive") ?? false
        let workoutType = userDefaults?.string(forKey: "currentWorkoutType") ?? "walking"
        let startTime = userDefaults?.double(forKey: "workoutStartTime") ?? 0

        let elapsedTime: TimeInterval
        if isActive && startTime > 0 {
            elapsedTime = Date().timeIntervalSince1970 - startTime
        } else {
            elapsedTime = 0
        }

        return WorkoutEntry(
            date: Date(),
            isWorkoutActive: isActive,
            workoutType: workoutType,
            elapsedTime: elapsedTime
        )
    }
}

struct WorkoutComplication: Widget {
    let kind: String = "WorkoutComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutProvider()) { entry in
            WorkoutComplicationView(entry: entry)
        }
        .configurationDisplayName("Workout")
        .description("Start a workout or see active workout status.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct WorkoutComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: WorkoutEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.isWorkoutActive {
                VStack(spacing: 2) {
                    Image(systemName: entry.workoutType == "running" ? "figure.run" : "figure.walk")
                        .font(.title3)

                    Text(formatDuration(entry.elapsedTime))
                        .font(.system(size: 10, weight: .medium))
                }
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.title)
            }
        }
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: entry.isWorkoutActive ?
                  (entry.workoutType == "running" ? "figure.run" : "figure.walk") :
                    "play.circle")
                .font(.title2)

            if entry.isWorkoutActive {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.workoutType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatDuration(entry.elapsedTime))
                        .font(.headline)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start")
                        .font(.headline)

                    Text("Workout")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var inlineView: some View {
        if entry.isWorkoutActive {
            HStack(spacing: 4) {
                Image(systemName: entry.workoutType == "running" ? "figure.run" : "figure.walk")
                Text(formatDuration(entry.elapsedTime))
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "play.circle")
                Text("Start Workout")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview(as: .accessoryCircular) {
    WorkoutComplication()
} timeline: {
    WorkoutEntry(date: Date(), isWorkoutActive: false, workoutType: "walking", elapsedTime: 0)
    WorkoutEntry(date: Date(), isWorkoutActive: true, workoutType: "walking", elapsedTime: 1234)
}
