import SwiftUI
import SwiftData
import WatchConnectivity

@main
struct StepSyncWatchApp: App {
    let modelContainer: ModelContainer

    @State private var healthKitManager = HealthKitManager.shared
    @State private var stepCountService = StepCountService()
    @State private var workoutSessionManager = WorkoutSessionManager.shared
    @State private var quickStartState = QuickStartState.shared

    /// WatchConnectivity manager for iPhone communication
    private var connectivityManager: WatchConnectivityManager {
        WatchConnectivityManager.shared
    }

    /// Tracks if a workout was requested from iPhone
    @State private var pendingWorkoutFromPhone: (type: WorkoutType, environment: WorkoutEnvironment)?

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

        // Initialize WatchConnectivity early to ensure session is activated
        // This must happen in init() to catch messages even when app is in background
        setupWatchConnectivity()
    }

    /// Sets up WatchConnectivity to receive commands from iPhone
    private func setupWatchConnectivity() {
        let connectivityManager = WatchConnectivityManager.shared

        connectivityManager.onWorkoutCommandReceived = { commandData in
            print("StepSyncWatch: Received workout command in app: \(commandData.command)")
            Task { @MainActor in
                self.handleWorkoutCommand(commandData)
            }
        }

        print("StepSyncWatch: WatchConnectivity initialized in app init")
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .modelContainer(modelContainer)
                .environment(healthKitManager)
                .environment(stepCountService)
                .environment(workoutSessionManager)
                .environment(quickStartState)
                .task {
                    await requestHealthKitAuthorization()
                    stepCountService.configure(with: modelContainer.mainContext)
                }
                .onOpenURL { url in
                    print("StepSyncWatchApp: Received URL: \(url)")
                    // Don't show picker if a workout is already active
                    guard !workoutSessionManager.isSessionActive else {
                        print("StepSyncWatchApp: Workout already active, ignoring URL")
                        return
                    }
                    quickStartState.handleURL(url)
                }
        }
    }

    /// Handles workout commands received from iPhone
    private func handleWorkoutCommand(_ commandData: WorkoutCommandData) {
        print("StepSyncWatch: Received workout command: \(commandData.command)")

        switch commandData.command {
        case .startWorkout:
            guard let typeString = commandData.workoutType,
                  let envString = commandData.workoutEnvironment,
                  let type = WorkoutType(rawValue: typeString),
                  let environment = WorkoutEnvironment(rawValue: envString) else {
                print("StepSyncWatch: Invalid workout parameters")
                connectivityManager.sendWorkoutStartedConfirmation(success: false, errorMessage: "Invalid workout parameters")
                return
            }

            // Start the workout
            Task {
                await startWorkoutFromPhone(type: type, environment: environment)
            }

        case .pauseWorkout:
            workoutSessionManager.pauseWorkout()

        case .resumeWorkout:
            workoutSessionManager.resumeWorkout()

        case .endWorkout:
            Task {
                _ = try? await workoutSessionManager.endWorkout()
            }

        default:
            break
        }
    }

    /// Starts a workout requested from iPhone
    @MainActor
    private func startWorkoutFromPhone(type: WorkoutType, environment: WorkoutEnvironment) async {
        print("StepSyncWatch: Starting workout from iPhone request - type: \(type), environment: \(environment)")

        do {
            try await workoutSessionManager.startWorkout(type: type, environment: environment)

            // Create a Workout record
            let workout = Workout(type: type, environment: environment)
            modelContainer.mainContext.insert(workout)
            try? modelContainer.mainContext.save()

            // Send confirmation back to iPhone
            connectivityManager.sendWorkoutStartedConfirmation(success: true)

            print("StepSyncWatch: Workout started successfully from iPhone request")
        } catch {
            print("StepSyncWatch: Failed to start workout from iPhone: \(error)")
            connectivityManager.sendWorkoutStartedConfirmation(success: false, errorMessage: error.localizedDescription)
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
