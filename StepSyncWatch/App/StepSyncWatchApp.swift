import SwiftUI
import SwiftData

@main
struct StepSyncWatchApp: App {
    let modelContainer: ModelContainer

    @State private var healthKitManager = HealthKitManager.shared
    @State private var stepCountService = StepCountService()
    @State private var workoutSessionManager = WorkoutSessionManager.shared

    init() {
        let schema = Schema([
            StepGoal.self,
            DailyStepRecord.self,
            Workout.self,
            WorkoutRoutePoint.self,
            HeartRateSample.self,
            Achievement.self,
            Streak.self,
            UserSettings.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier("group.com.nwwsolutions.steppingszn"),
            cloudKitDatabase: .private("iCloud.com.nwwsolutions.stepsync")
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .modelContainer(modelContainer)
                .environment(healthKitManager)
                .environment(stepCountService)
                .environment(workoutSessionManager)
                .task {
                    await requestHealthKitAuthorization()
                    stepCountService.configure(with: modelContainer.mainContext)
                }
        }
    }

    private func requestHealthKitAuthorization() async {
        guard healthKitManager.isHealthDataAvailable else {
            print("StepSyncWatch: HealthKit not available on this device")
            return
        }

        do {
            try await healthKitManager.requestAuthorization()
            print("StepSyncWatch: HealthKit authorization successful")

            // Enable background delivery for real-time updates
            await healthKitManager.enableBackgroundDelivery()

            // Fetch initial data
            await stepCountService.refreshTodayData()

            // Start observing step count changes for real-time updates
            stepCountService.startObservingSteps()

            print("StepSyncWatch: Step count observation started, current steps: \(stepCountService.todayStepCount)")
        } catch {
            print("StepSyncWatch: HealthKit authorization failed: \(error)")
        }
    }
}
