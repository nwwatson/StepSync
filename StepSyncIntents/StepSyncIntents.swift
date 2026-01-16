import AppIntents
import Foundation

struct GetStepCountIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Today's Step Count"
    static let description = IntentDescription("Returns your current step count for today")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        let stepCount = userDefaults?.integer(forKey: "todayStepCount") ?? 0

        return .result(value: stepCount)
    }
}

struct GetStepGoalIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Step Goal"
    static let description = IntentDescription("Returns your daily step goal")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        let goalTarget = userDefaults?.integer(forKey: "dailyGoal") ?? 10000

        return .result(value: goalTarget)
    }
}

struct GetStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Streak"
    static let description = IntentDescription("Returns your current streak in days")

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        let streak = userDefaults?.integer(forKey: "currentStreak") ?? 0

        return .result(value: streak)
    }
}

struct IsGoalAchievedIntent: AppIntent {
    static let title: LocalizedStringResource = "Check if Goal is Achieved"
    static let description = IntentDescription("Returns whether today's step goal has been achieved")

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        let stepCount = userDefaults?.integer(forKey: "todayStepCount") ?? 0
        let goalTarget = userDefaults?.integer(forKey: "dailyGoal") ?? 10000

        return .result(value: stepCount >= goalTarget)
    }
}

struct StartWalkingIntent: AppIntent {
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

struct StartRunningIntent: AppIntent {
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

struct StopWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Workout"
    static let description = IntentDescription("Stops the current workout")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        userDefaults?.set(true, forKey: "shouldStopWorkout")

        return .result()
    }
}

struct StepSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetStepCountIntent(),
            phrases: [
                "How many steps have I taken today with \(.applicationName)?",
                "Get my step count from \(.applicationName)",
                "What's my step count in \(.applicationName)?"
            ],
            shortTitle: "Step Count",
            systemImageName: "figure.walk"
        )

        AppShortcut(
            intent: IsGoalAchievedIntent(),
            phrases: [
                "Have I reached my step goal in \(.applicationName)?",
                "Did I achieve my goal in \(.applicationName)?",
                "Check my step goal in \(.applicationName)"
            ],
            shortTitle: "Goal Status",
            systemImageName: "target"
        )

        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my streak in \(.applicationName)?",
                "How long is my step streak in \(.applicationName)?",
                "Get my streak from \(.applicationName)"
            ],
            shortTitle: "Streak",
            systemImageName: "flame"
        )

        AppShortcut(
            intent: StartWalkingIntent(),
            phrases: [
                "Start a walk with \(.applicationName)",
                "Begin walking workout in \(.applicationName)",
                "Start walking in \(.applicationName)"
            ],
            shortTitle: "Start Walking",
            systemImageName: "figure.walk"
        )

        AppShortcut(
            intent: StartRunningIntent(),
            phrases: [
                "Start a run with \(.applicationName)",
                "Begin running workout in \(.applicationName)",
                "Start running in \(.applicationName)"
            ],
            shortTitle: "Start Running",
            systemImageName: "figure.run"
        )
    }
}
