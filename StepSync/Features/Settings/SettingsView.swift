import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.createdAt, order: .reverse) private var settings: [UserSettings]
    @Query(sort: \StepGoal.createdAt, order: .reverse) private var goals: [StepGoal]

    @State private var showingHealthKitSettings = false
    @State private var showingAbout = false

    private var currentSettings: UserSettings? {
        settings.first
    }

    var body: some View {
        NavigationStack {
            List {
                goalsSection

                notificationsSection

                workoutSection

                unitsSection

                aboutSection
            }
            .navigationTitle("Settings")
            .task {
                await ensureSettingsExist()
            }
        }
    }

    private var goalsSection: some View {
        Section("Goals") {
            if let goal = goals.first {
                LabeledContent("Daily Step Goal") {
                    Text("\(goal.dailyTarget.formatted()) steps")
                }

                LabeledContent("Current Level") {
                    Text("Level \(goal.progressionLevel)")
                }

                LabeledContent("Streak") {
                    Text("\(goal.consecutiveDaysAchieved) days")
                }
            }

            NavigationLink("Edit Step Goal") {
                GoalSettingsSheet()
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            if let settings = currentSettings {
                Toggle("Daily Reminder", isOn: Binding(
                    get: { settings.dailyReminderEnabled },
                    set: { newValue in
                        settings.dailyReminderEnabled = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))

                if settings.dailyReminderEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { settings.dailyReminderTime },
                            set: { newValue in
                                settings.dailyReminderTime = newValue
                                settings.update()
                                try? modelContext.save()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle("Streak Reminder", isOn: Binding(
                    get: { settings.streakReminderEnabled },
                    set: { newValue in
                        settings.streakReminderEnabled = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))

                Toggle("Goal Achieved Notification", isOn: Binding(
                    get: { settings.goalAchievedNotificationEnabled },
                    set: { newValue in
                        settings.goalAchievedNotificationEnabled = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))

                Toggle("Inactivity Reminder", isOn: Binding(
                    get: { settings.inactivityReminderEnabled },
                    set: { newValue in
                        settings.inactivityReminderEnabled = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))
            }
        }
    }

    private var workoutSection: some View {
        Section("Workout") {
            if let settings = currentSettings {
                Toggle("Show Heart Rate", isOn: Binding(
                    get: { settings.showHeartRateDuringWorkout },
                    set: { newValue in
                        settings.showHeartRateDuringWorkout = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))

                Toggle("Show Cadence", isOn: Binding(
                    get: { settings.showCadenceDuringWorkout },
                    set: { newValue in
                        settings.showCadenceDuringWorkout = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))

                Toggle("Show Pace", isOn: Binding(
                    get: { settings.showPaceDuringWorkout },
                    set: { newValue in
                        settings.showPaceDuringWorkout = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))

                Toggle("Haptic Feedback", isOn: Binding(
                    get: { settings.hapticFeedbackEnabled },
                    set: { newValue in
                        settings.hapticFeedbackEnabled = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))
            }
        }
    }

    private var unitsSection: some View {
        Section("Units") {
            if let settings = currentSettings {
                Toggle("Use Metric Units", isOn: Binding(
                    get: { settings.useMetricUnits },
                    set: { newValue in
                        settings.useMetricUnits = newValue
                        settings.update()
                        try? modelContext.save()
                    }
                ))
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text("1.0.0")
            }

            Link(destination: URL(string: "https://apple.com/health")!) {
                HStack {
                    Text("Health & Privacy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }

            Link(destination: URL(string: "https://apple.com/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
        }
    }

    private func ensureSettingsExist() async {
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserSettings.self, StepGoal.self])
        .environment(HealthKitManager.shared)
}
