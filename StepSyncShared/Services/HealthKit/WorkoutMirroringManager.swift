import Foundation
import HealthKit
import Observation
import WatchConnectivity
#if os(iOS)
import ActivityKit
#endif

/// Manages workout mirroring between iPhone and Apple Watch.
/// When a workout is started on iPhone, it sends a command to the Watch
/// which then runs the actual workout session with sensor access and mirrors back.
@Observable
public final class WorkoutMirroringManager: NSObject, @unchecked Sendable {
    public static let shared = WorkoutMirroringManager()

    private let healthStore = HKHealthStore()
    private let appGroupID = "group.com.nwwsolutions.steppingszn"
    private let connectivityManager = WatchConnectivityManager.shared

    #if os(iOS)
    private var mirroredSession: HKWorkoutSession?

    /// Live Activity manager for displaying workout on lock screen
    @available(iOS 16.1, *)
    private var liveActivityManager: LiveActivityManager {
        LiveActivityManager.shared
    }
    #endif

    public private(set) var isMirroring = false
    public private(set) var mirroringError: Error?
    public private(set) var currentWorkoutType: WorkoutType?
    public private(set) var currentWorkoutEnvironment: WorkoutEnvironment?
    public private(set) var isWatchInitiatedWorkout = false

    /// Indicates if the Watch is reachable for starting workouts
    public var isWatchReachable: Bool {
        #if os(iOS)
        return connectivityManager.isReachable
        #else
        return false
        #endif
    }

    // Metrics received from watch
    public private(set) var elapsedTime: TimeInterval = 0
    public private(set) var distance: Double = 0
    public private(set) var stepCount: Int = 0
    public private(set) var activeCalories: Double = 0
    public private(set) var heartRate: Double = 0
    public private(set) var averageHeartRate: Double = 0
    public private(set) var currentPace: Double = 0
    public private(set) var isPaused: Bool = false

    private var metricsTimer: Timer?
    private var sessionStartDate: Date?

    /// Steps counted before the workout started - used to avoid double-counting in Live Activity progress
    private var stepsBeforeWorkout: Int = 0

    private override init() {
        super.init()
        print("WorkoutMirroringManager: Singleton initialized")
        #if os(iOS)
        setupWatchWorkoutHandler()
        #endif
    }

    #if os(iOS)
    /// Sets up the handler for receiving workout sessions started on Apple Watch
    private func setupWatchWorkoutHandler() {
        print("WorkoutMirroringManager: Setting up workoutSessionMirroringStartHandler")
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            print("WorkoutMirroringManager: 🎯 workoutSessionMirroringStartHandler CALLED - received mirrored session!")
            print("WorkoutMirroringManager: Session activity type: \(mirroredSession.workoutConfiguration.activityType.rawValue)")
            print("WorkoutMirroringManager: Session location type: \(mirroredSession.workoutConfiguration.locationType.rawValue)")
            Task { @MainActor in
                self?.handleWatchInitiatedWorkout(mirroredSession)
            }
        }
        print("WorkoutMirroringManager: workoutSessionMirroringStartHandler has been set")
    }

    /// Handles a workout session that was initiated on Apple Watch
    @MainActor
    private func handleWatchInitiatedWorkout(_ session: HKWorkoutSession) {
        print("WorkoutMirroringManager: handleWatchInitiatedWorkout called")

        guard !isMirroring else {
            print("WorkoutMirroringManager: Cannot start watch workout - session already active")
            return
        }

        print("WorkoutMirroringManager: Setting up mirrored session...")
        mirroredSession = session
        session.delegate = self

        // Extract workout type from configuration
        let activityType = session.workoutConfiguration.activityType
        currentWorkoutType = activityType == .running ? .running : .walking
        print("WorkoutMirroringManager: Workout type determined as: \(currentWorkoutType?.displayName ?? "unknown")")

        let locationType = session.workoutConfiguration.locationType
        currentWorkoutEnvironment = locationType == .indoor ? .indoor : .outdoor
        print("WorkoutMirroringManager: Environment determined as: \(currentWorkoutEnvironment?.displayName ?? "unknown")")

        isMirroring = true
        isWatchInitiatedWorkout = true
        sessionStartDate = Date()
        mirroringError = nil

        resetMetrics()
        startMetricsTimer()

        // Start Live Activity
        print("WorkoutMirroringManager: About to start Live Activity...")
        startLiveActivity()

        print("WorkoutMirroringManager: ✅ Completed handling watch-initiated workout session")
    }
    #endif

    #if os(iOS)
    private var builder: HKLiveWorkoutBuilder?

    /// Starts the Live Activity for the workout
    private func startLiveActivity() {
        guard #available(iOS 16.1, *) else {
            print("WorkoutMirroringManager: Live Activities require iOS 16.1+")
            return
        }

        print("WorkoutMirroringManager: startLiveActivity() called")

        // Debug print activity state before starting
        liveActivityManager.debugPrintActivityState()

        let userDefaults = UserDefaults(suiteName: appGroupID)
        let dailyGoal = userDefaults?.integer(forKey: "dailyGoal") ?? 10000
        let todaySteps = userDefaults?.integer(forKey: "todayStepCount") ?? 0

        // Store the steps before workout to avoid double-counting
        // (HealthKit updates todayStepCount in real-time during workouts)
        stepsBeforeWorkout = todaySteps

        let workoutTypeName = currentWorkoutType?.displayName ?? "Workout"
        let workoutIcon = currentWorkoutType?.systemImage ?? "figure.walk"

        print("WorkoutMirroringManager: Starting Live Activity - type: \(workoutTypeName), icon: \(workoutIcon), dailyGoal: \(dailyGoal), stepsBeforeWorkout: \(stepsBeforeWorkout)")

        let success = liveActivityManager.startWorkoutActivity(
            workoutType: workoutTypeName,
            workoutIcon: workoutIcon,
            dailyGoal: dailyGoal,
            initialSteps: 0,
            initialDailySteps: stepsBeforeWorkout
        )

        if success {
            print("WorkoutMirroringManager: ✅ Live Activity started successfully")
            // Debug print activity state after starting
            liveActivityManager.debugPrintActivityState()
        } else {
            print("WorkoutMirroringManager: ❌ Failed to start Live Activity - check if Live Activities are enabled in Settings")
        }
    }

    /// Updates the Live Activity with current metrics
    private func updateLiveActivity() {
        guard #available(iOS 16.1, *) else { return }

        // Use the stored stepsBeforeWorkout to avoid double-counting
        // (todayStepCount in UserDefaults gets updated by HealthKit during workout,
        // which would already include the workout steps)
        let totalDailySteps = stepsBeforeWorkout + stepCount

        liveActivityManager.updateWorkoutActivity(
            stepCount: stepCount,
            totalDailySteps: totalDailySteps,
            heartRate: Int(heartRate),
            distanceMeters: distance,
            elapsedSeconds: Int(elapsedTime),
            isPaused: isPaused
        )
    }

    /// Ends the Live Activity
    private func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }

        // Use the stored stepsBeforeWorkout to avoid double-counting
        let totalDailySteps = stepsBeforeWorkout + stepCount

        liveActivityManager.endWorkoutActivity(
            finalStepCount: stepCount,
            finalTotalDailySteps: totalDailySteps,
            finalHeartRate: Int(heartRate),
            finalDistanceMeters: distance,
            finalElapsedSeconds: Int(elapsedTime)
        )
    }

    /// Starts a workout on Apple Watch by sending a command via WatchConnectivity.
    /// The Watch will start the workout and mirror it back to iPhone.
    public func startMirroredWorkout(type: WorkoutType, environment: WorkoutEnvironment) async throws {
        guard !isMirroring else {
            throw WorkoutMirroringError.sessionAlreadyActive
        }

        // Try to start workout on Watch via WatchConnectivity
        print("WorkoutMirroringManager: Attempting to start workout on Apple Watch...")
        print("WorkoutMirroringManager: Watch reachable: \(connectivityManager.isReachable)")

        guard connectivityManager.canSendMessage else {
            throw WorkoutMirroringError.watchNotReachable
        }

        do {
            // Send command to Watch to start the workout
            try await connectivityManager.sendStartWorkoutCommand(type: type, environment: environment)

            // Store the workout type/environment for when we receive the mirrored session
            currentWorkoutType = type
            currentWorkoutEnvironment = environment

            print("WorkoutMirroringManager: Start workout command sent to Watch successfully")
            print("WorkoutMirroringManager: Waiting for Watch to start workout and mirror session back...")

            // The actual workout session will be handled by handleWatchInitiatedWorkout
            // when the Watch mirrors the session back to iPhone
        } catch let error as WatchConnectivityError {
            print("WorkoutMirroringManager: Failed to send command to Watch: \(error)")
            mirroringError = error
            throw WorkoutMirroringError.watchNotReachable
        } catch {
            print("WorkoutMirroringManager: Unexpected error: \(error)")
            mirroringError = error
            throw WorkoutMirroringError.failedToStart(error)
        }
    }

    /// Starts a workout session locally on iPhone (without Watch).
    /// This can be used as a fallback when Watch is not available.
    public func startLocalWorkout(type: WorkoutType, environment: WorkoutEnvironment) async throws {
        guard !isMirroring else {
            throw WorkoutMirroringError.sessionAlreadyActive
        }

        let activityType: HKWorkoutActivityType = type == .walking ? .walking : .running
        let locationType: HKWorkoutSessionLocationType = environment == .outdoor ? .outdoor : .indoor

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = locationType

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            mirroredSession = session

            let workoutBuilder = session.associatedWorkoutBuilder()
            workoutBuilder.delegate = self

            let dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Explicitly enable step count collection (not automatically collected)
            if let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                dataSource.enableCollection(for: stepCountType, predicate: nil)
            }

            workoutBuilder.dataSource = dataSource
            builder = workoutBuilder

            print("WorkoutMirroringManager: Starting local workout session on iPhone...")

            let startDate = Date()
            session.startActivity(with: startDate)
            try await workoutBuilder.beginCollection(at: startDate)

            isMirroring = true
            isWatchInitiatedWorkout = false
            currentWorkoutType = type
            currentWorkoutEnvironment = environment
            sessionStartDate = startDate
            mirroringError = nil

            resetMetrics()
            startMetricsTimer()

            // Start Live Activity
            startLiveActivity()

            print("WorkoutMirroringManager: Started local workout session on iPhone at \(startDate)")
        } catch {
            mirroringError = error
            throw WorkoutMirroringError.failedToStart(error)
        }
    }

    /// Pauses the workout session
    public func pauseWorkout() {
        mirroredSession?.pause()
    }

    /// Resumes the workout session
    public func resumeWorkout() {
        mirroredSession?.resume()
    }

    /// Ends the workout session
    public func endWorkout() async throws {
        guard isMirroring, let session = mirroredSession else {
            throw WorkoutMirroringError.noActiveSession
        }

        session.end()

        if let workoutBuilder = builder {
            try await workoutBuilder.endCollection(at: Date())
            _ = try await workoutBuilder.finishWorkout()
        }

        // End Live Activity
        endLiveActivity()

        cleanup()
        stopMetricsTimer()
    }
    #endif

    private func resetMetrics() {
        elapsedTime = 0
        distance = 0
        stepCount = 0
        activeCalories = 0
        heartRate = 0
        averageHeartRate = 0
        currentPace = 0
        isPaused = false
        stepsBeforeWorkout = 0
    }

    private func cleanup() {
        #if os(iOS)
        mirroredSession = nil
        builder = nil
        #endif
        isMirroring = false
        isWatchInitiatedWorkout = false
        currentWorkoutType = nil
        currentWorkoutEnvironment = nil
        sessionStartDate = nil
        mirroringError = nil
    }

    private func startMetricsTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateElapsedTime()
                }
            }
            // Ensure timer fires even during UI interactions
            if let timer = self.metricsTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
            print("WorkoutMirroringManager: Metrics timer started")
        }
    }

    private func stopMetricsTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.metricsTimer?.invalidate()
            self?.metricsTimer = nil
            print("WorkoutMirroringManager: Metrics timer stopped")
        }
    }

    private func updateElapsedTime() {
        guard let startDate = sessionStartDate, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startDate)
    }

    // MARK: - Formatted Strings

    public var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var formattedDistance: String {
        let distanceInMiles = distance / 1609.34
        return String(format: "%.2f", distanceInMiles)
    }

    public var formattedPace: String {
        guard currentPace > 0 else { return "--:--" }
        let paceMinutes = Int(currentPace) / 60
        let paceSeconds = Int(currentPace) % 60
        return String(format: "%d:%02d", paceMinutes, paceSeconds)
    }

    public var formattedHeartRate: String {
        guard heartRate > 0 else { return "--" }
        return String(format: "%.0f", heartRate)
    }
}

#if os(iOS)
extension WorkoutMirroringManager: HKWorkoutSessionDelegate {
    public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch toState {
            case .running:
                self.isPaused = false
                self.isMirroring = true
                self.updateLiveActivity()
            case .paused:
                self.isPaused = true
                self.updateLiveActivity()
            case .ended:
                self.isMirroring = false
                self.stopMetricsTimer()
                self.endLiveActivity()
            default:
                break
            }
        }
    }

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("WorkoutMirroringManager: Session failed with error: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.mirroringError = error
            self?.cleanup()
        }
    }

    public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        // Receive metrics data from the Watch
        for dataItem in data {
            if let metrics = try? JSONDecoder().decode(WorkoutMetricsData.self, from: dataItem) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.distance = metrics.distance
                    self.stepCount = metrics.stepCount
                    self.activeCalories = metrics.activeCalories
                    self.heartRate = metrics.heartRate
                    self.averageHeartRate = metrics.averageHeartRate
                    self.currentPace = metrics.currentPace

                    // Update Live Activity with new metrics
                    self.updateLiveActivity()
                }
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutMirroringManager: HKLiveWorkoutBuilderDelegate {
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Log collected types for debugging
        let typeNames = collectedTypes.compactMap { $0.identifier }
        print("WorkoutMirroringManager: Received data for types: \(typeNames)")

        // Update metrics from the builder's statistics
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Distance
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
               let statistics = workoutBuilder.statistics(for: distanceType),
               let sum = statistics.sumQuantity() {
                let newDistance = sum.doubleValue(for: .meter())
                self.distance = newDistance
                print("WorkoutMirroringManager: Distance updated to \(newDistance) meters")

                // Calculate pace (seconds per mile) from distance and elapsed time
                if self.elapsedTime > 0 && self.distance > 0 {
                    let speedMetersPerSecond = self.distance / self.elapsedTime
                    if speedMetersPerSecond > 0 {
                        // Convert to seconds per mile
                        self.currentPace = 1609.34 / speedMetersPerSecond
                    }
                }
            }

            // Step count
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
               let statistics = workoutBuilder.statistics(for: stepType),
               let sum = statistics.sumQuantity() {
                let newSteps = Int(sum.doubleValue(for: .count()))
                self.stepCount = newSteps
                print("WorkoutMirroringManager: Step count updated to \(newSteps)")
            }

            // Active calories
            if let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               let statistics = workoutBuilder.statistics(for: caloriesType),
               let sum = statistics.sumQuantity() {
                let newCalories = sum.doubleValue(for: .kilocalorie())
                self.activeCalories = newCalories
                print("WorkoutMirroringManager: Calories updated to \(newCalories)")
            }

            // Heart rate (most recent)
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
               let statistics = workoutBuilder.statistics(for: heartRateType),
               let mostRecent = statistics.mostRecentQuantity() {
                let newHeartRate = mostRecent.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                self.heartRate = newHeartRate
                print("WorkoutMirroringManager: Heart rate updated to \(newHeartRate)")
            }

            // Average heart rate
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
               let statistics = workoutBuilder.statistics(for: heartRateType),
               let average = statistics.averageQuantity() {
                self.averageHeartRate = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }

            // Update Live Activity with new metrics
            self.updateLiveActivity()
        }
    }
}
#endif

// MARK: - Data Transfer Types

public struct WorkoutMetricsData: Codable, Sendable {
    public let distance: Double
    public let stepCount: Int
    public let activeCalories: Double
    public let heartRate: Double
    public let averageHeartRate: Double
    public let currentPace: Double

    public init(
        distance: Double,
        stepCount: Int,
        activeCalories: Double,
        heartRate: Double,
        averageHeartRate: Double,
        currentPace: Double
    ) {
        self.distance = distance
        self.stepCount = stepCount
        self.activeCalories = activeCalories
        self.heartRate = heartRate
        self.averageHeartRate = averageHeartRate
        self.currentPace = currentPace
    }
}

// MARK: - Errors

public enum WorkoutMirroringError: LocalizedError {
    case sessionAlreadyActive
    case noActiveSession
    case mirroringFailed
    case failedToStart(Error)
    case watchNotReachable

    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "A workout session is already active"
        case .noActiveSession:
            return "No active workout session"
        case .mirroringFailed:
            return "Failed to mirror workout to Apple Watch"
        case .failedToStart(let error):
            return "Failed to start workout: \(error.localizedDescription)"
        case .watchNotReachable:
            return "Apple Watch is not reachable. Make sure it's nearby and unlocked."
        }
    }
}
