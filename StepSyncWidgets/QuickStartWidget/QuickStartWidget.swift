import WidgetKit
import SwiftUI
import AppIntents

struct QuickStartEntry: TimelineEntry {
    let date: Date
    let isWorkoutActive: Bool
}

struct QuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: Date(), isWorkoutActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        let entry = QuickStartEntry(date: Date(), isWorkoutActive: false)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        let isActive = userDefaults?.bool(forKey: "isWorkoutActive") ?? false

        let entry = QuickStartEntry(date: Date(), isWorkoutActive: isActive)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
}

struct QuickStartWidget: Widget {
    let kind: String = "QuickStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider()) { entry in
            QuickStartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Start")
        .description("Start a workout with one tap.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickStartWidgetView: View {
    let entry: QuickStartEntry

    var body: some View {
        if entry.isWorkoutActive {
            activeWorkoutView
        } else {
            startWorkoutView
        }
    }

    private var startWorkoutView: some View {
        VStack(spacing: 12) {
            Text("Quick Start")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button(intent: WidgetStartWalkingIntent()) {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                        Text("Walk")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(intent: WidgetStartRunningIntent()) {
                    VStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.title2)
                        Text("Run")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var activeWorkoutView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.title)

            Text("Workout Active")
                .font(.headline)

            Button(intent: WidgetStopWorkoutIntent()) {
                Text("Stop")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct WidgetStartWalkingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Walking Workout"
    static let description = IntentDescription("Starts a walking workout")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        userDefaults?.set("walking", forKey: "pendingWorkoutType")
        userDefaults?.set(true, forKey: "shouldStartWorkout")

        return .result()
    }
}

struct WidgetStartRunningIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Running Workout"
    static let description = IntentDescription("Starts a running workout")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        userDefaults?.set("running", forKey: "pendingWorkoutType")
        userDefaults?.set(true, forKey: "shouldStartWorkout")

        return .result()
    }
}

struct WidgetStopWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Workout"
    static let description = IntentDescription("Stops the current workout")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        userDefaults?.set(true, forKey: "shouldStopWorkout")

        return .result()
    }
}

#Preview(as: .systemSmall) {
    QuickStartWidget()
} timeline: {
    QuickStartEntry(date: Date(), isWorkoutActive: false)
    QuickStartEntry(date: Date(), isWorkoutActive: true)
}
