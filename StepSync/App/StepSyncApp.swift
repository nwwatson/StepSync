import SwiftUI
import SwiftData

@main
struct StepSyncApp: App {
    let modelContainer: ModelContainer
    private let appGroupID = "group.com.nwwsolutions.steppingszn"

    @Environment(\.scenePhase) private var scenePhase
    @State private var healthKitManager = HealthKitManager.shared
    @State private var stepCountService = StepCountService()
    @State private var workoutSessionManager = WorkoutSessionManager.shared
    @State private var workoutMirroringManager = WorkoutMirroringManager.shared
    @State private var locationManager = LocationManager.shared

    @available(iOS 16.1, *)
    private var liveActivityManager: LiveActivityManager {
        LiveActivityManager.shared
    }

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

        // Initialize WorkoutMirroringManager early to set up the mirroring handler
        // This ensures we can receive workout sessions from Apple Watch even when
        // the app is launched from background
        _ = WorkoutMirroringManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(healthKitManager)
                .environment(stepCountService)
                .environment(workoutSessionManager)
                .environment(workoutMirroringManager)
                .environment(locationManager)
                .task {
                    await requestHealthKitAuthorization()
                    stepCountService.configure(with: modelContainer.mainContext)
                }
                .onAppear {
                    checkForLiveActivityRequests()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        checkForLiveActivityRequests()
                    }
                }
        }
    }

    /// Checks UserDefaults for pending Live Activity requests (when app is opened from background)
    private func checkForLiveActivityRequests() {
        let userDefaults = UserDefaults(suiteName: appGroupID)

        // Check for pause request
        if userDefaults?.bool(forKey: "workoutPauseRequested") == true {
            userDefaults?.set(false, forKey: "workoutPauseRequested")
            handleTogglePauseRequest()
        }

        // Check for stop request
        if userDefaults?.bool(forKey: "workoutStopRequested") == true {
            userDefaults?.set(false, forKey: "workoutStopRequested")
            handleStopWorkoutRequest()
        }
    }

    /// Handles toggle pause/resume request from Live Activity
    private func handleTogglePauseRequest() {
        if workoutMirroringManager.isPaused {
            workoutMirroringManager.resumeWorkout()
        } else {
            workoutMirroringManager.pauseWorkout()
        }
    }

    /// Handles stop workout request from Live Activity
    private func handleStopWorkoutRequest() {
        Task {
            do {
                try await workoutMirroringManager.endWorkout()
            } catch {
                print("StepSyncApp: Failed to stop workout: \(error)")
            }
        }
    }

    private func requestHealthKitAuthorization() async {
        guard healthKitManager.isHealthDataAvailable else {
            print("StepSync: HealthKit not available on this device")
            return
        }

        do {
            try await healthKitManager.requestAuthorization()
            print("StepSync: HealthKit authorization successful")

            // Enable background delivery for real-time updates
            await healthKitManager.enableBackgroundDelivery()

            // Fetch initial data
            await stepCountService.refreshTodayData()

            // Start observing step count changes for real-time updates
            stepCountService.startObservingSteps()

            print("StepSync: Step count observation started, current steps: \(stepCountService.todayStepCount)")
        } catch {
            print("StepSync: HealthKit authorization failed: \(error)")
        }
    }
}
