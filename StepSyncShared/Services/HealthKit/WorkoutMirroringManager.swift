import Foundation
import HealthKit
import Observation

/// Manages workout mirroring between iPhone and Apple Watch.
/// When a workout is started on iPhone, it can be mirrored to the Watch
/// which then runs the actual workout session with sensor access.
@Observable
public final class WorkoutMirroringManager: NSObject, @unchecked Sendable {
    public static let shared = WorkoutMirroringManager()

    private let healthStore = HKHealthStore()

    #if os(iOS)
    private var mirroredSession: HKWorkoutSession?
    #endif

    public private(set) var isMirroring = false
    public private(set) var mirroringError: Error?
    public private(set) var currentWorkoutType: WorkoutType?
    public private(set) var currentWorkoutEnvironment: WorkoutEnvironment?

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

    private override init() {
        super.init()
    }

    #if os(iOS)
    private var builder: HKLiveWorkoutBuilder?

    /// Starts a workout session on the iPhone.
    /// In iOS 26+, workouts run natively on iPhone without needing Apple Watch.
    public func startMirroredWorkout(type: WorkoutType, environment: WorkoutEnvironment) async throws {
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

            // In iOS 26+, start the workout session directly on iPhone
            let workoutBuilder = session.associatedWorkoutBuilder()
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            builder = workoutBuilder

            let startDate = Date()
            session.startActivity(with: startDate)
            try await workoutBuilder.beginCollection(at: startDate)

            isMirroring = true
            currentWorkoutType = type
            currentWorkoutEnvironment = environment
            sessionStartDate = startDate
            mirroringError = nil

            resetMetrics()
            startMetricsTimer()

            print("WorkoutMirroringManager: Started workout session on iPhone")
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
    }

    private func cleanup() {
        #if os(iOS)
        mirroredSession = nil
        builder = nil
        #endif
        isMirroring = false
        currentWorkoutType = nil
        currentWorkoutEnvironment = nil
        sessionStartDate = nil
        mirroringError = nil
    }

    private func startMetricsTimer() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }

    private func stopMetricsTimer() {
        metricsTimer?.invalidate()
        metricsTimer = nil
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
            switch toState {
            case .running:
                self?.isPaused = false
                self?.isMirroring = true
            case .paused:
                self?.isPaused = true
            case .ended:
                self?.isMirroring = false
                self?.stopMetricsTimer()
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
                    self?.distance = metrics.distance
                    self?.stepCount = metrics.stepCount
                    self?.activeCalories = metrics.activeCalories
                    self?.heartRate = metrics.heartRate
                    self?.averageHeartRate = metrics.averageHeartRate
                    self?.currentPace = metrics.currentPace
                }
            }
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
