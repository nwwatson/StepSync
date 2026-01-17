import AppIntents
import Foundation

// MARK: - Constants

private enum WorkoutIntentConstants {
    static let appGroupID = "group.com.nwwsolutions.steppingszn"
    static let pauseRequestedKey = "workoutPauseRequested"
    static let stopRequestedKey = "workoutStopRequested"
}

/// App Intent to toggle pause/resume for the active workout from Live Activity
@available(iOS 16.0, *)
struct TogglePauseWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Pause Workout"
    static let description = IntentDescription("Pauses or resumes the current workout")

    /// Opens the main app to handle the intent
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // Set flag in UserDefaults for the main app to read
        let userDefaults = UserDefaults(suiteName: WorkoutIntentConstants.appGroupID)
        userDefaults?.set(true, forKey: WorkoutIntentConstants.pauseRequestedKey)
        userDefaults?.synchronize()

        return .result()
    }
}

/// App Intent to stop the active workout from Live Activity
@available(iOS 16.0, *)
struct StopWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Workout"
    static let description = IntentDescription("Stops the current workout")

    /// Opens the main app to complete the stop action
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Set flag in UserDefaults for the main app to read
        let userDefaults = UserDefaults(suiteName: WorkoutIntentConstants.appGroupID)
        userDefaults?.set(true, forKey: WorkoutIntentConstants.stopRequestedKey)
        userDefaults?.synchronize()

        return .result()
    }
}

// MARK: - Intent Shortcuts

@available(iOS 16.0, *)
struct WorkoutIntentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TogglePauseWorkoutIntent(),
            phrases: [
                "Pause my \(.applicationName) workout",
                "Resume my \(.applicationName) workout"
            ],
            shortTitle: "Toggle Pause",
            systemImageName: "pause.circle"
        )

        AppShortcut(
            intent: StopWorkoutIntent(),
            phrases: [
                "Stop my \(.applicationName) workout",
                "End my \(.applicationName) workout"
            ],
            shortTitle: "Stop Workout",
            systemImageName: "stop.circle"
        )
    }
}
