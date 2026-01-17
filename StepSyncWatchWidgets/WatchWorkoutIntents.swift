import AppIntents

/// AppIntent for starting a walking workout from the Watch complication
struct WatchStartWalkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Walk"
    static let description = IntentDescription("Start a walking workout from the Watch face")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        userDefaults?.set("walking", forKey: "pendingWatchWorkoutType")
        userDefaults?.set(true, forKey: "showQuickStartPicker")
        return .result()
    }
}

/// AppIntent for starting a running workout from the Watch complication
struct WatchStartRunIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Run"
    static let description = IntentDescription("Start a running workout from the Watch face")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        let userDefaults = UserDefaults(suiteName: "group.com.nwwsolutions.steppingszn")
        userDefaults?.set("running", forKey: "pendingWatchWorkoutType")
        userDefaults?.set(true, forKey: "showQuickStartPicker")
        return .result()
    }
}
