import Foundation
import HealthKit
import Observation

#if os(watchOS)
import WatchKit
#endif

@Observable
public final class WorkoutSessionManager: NSObject, @unchecked Sendable {
    public static let shared = WorkoutSessionManager()

    private let healthStore = HKHealthStore()

    #if os(watchOS)
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    #endif

    public private(set) var isSessionActive = false
    public private(set) var currentWorkoutType: WorkoutType?
    public private(set) var currentWorkoutEnvironment: WorkoutEnvironment?
    public private(set) var sessionStartDate: Date?

    public private(set) var elapsedTime: TimeInterval = 0
    public private(set) var distance: Double = 0
    public private(set) var stepCount: Int = 0
    public private(set) var activeCalories: Double = 0
    public private(set) var heartRate: Double = 0
    public private(set) var averageHeartRate: Double = 0
    public private(set) var currentPace: Double = 0
    public private(set) var averagePace: Double = 0
    public private(set) var cadence: Double = 0
    public private(set) var isPaused: Bool = false

    private var heartRateSamples: [Double] = []
    private var updateTimer: Timer?
    private var pausedTime: TimeInterval = 0
    private var lastPauseDate: Date?
    private var isMirroredSession: Bool = false
    private var metricsSendTimer: Timer?

    private override init() {
        super.init()
        #if os(watchOS)
        setupMirroringHandler()
        #endif
    }

    #if os(watchOS)
    /// Sets up the handler for receiving mirrored workout sessions from iPhone
    private func setupMirroringHandler() {
        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.handleMirroredSession(mirroredSession)
            }
        }
    }

    /// Handles a mirrored workout session started from iPhone
    private func handleMirroredSession(_ mirroredSession: HKWorkoutSession) {
        guard !isSessionActive else {
            print("WorkoutSessionManager: Cannot start mirrored session - session already active")
            return
        }

        session = mirroredSession
        builder = mirroredSession.associatedWorkoutBuilder()

        builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: mirroredSession.workoutConfiguration
        )

        session?.delegate = self
        builder?.delegate = self

        // Determine workout type from configuration
        let activityType = mirroredSession.workoutConfiguration.activityType
        currentWorkoutType = activityType == .running ? .running : .walking

        let locationType = mirroredSession.workoutConfiguration.locationType
        currentWorkoutEnvironment = locationType == .indoor ? .indoor : .outdoor

        let startDate = Date()
        sessionStartDate = startDate
        isMirroredSession = true

        Task {
            do {
                try await builder?.beginCollection(at: startDate)
                await MainActor.run {
                    self.isSessionActive = true
                    self.resetMetrics()
                    self.startUpdateTimer()
                    self.startMetricsSendTimer()
                    WKInterfaceDevice.current().play(.start)
                    print("WorkoutSessionManager: Started mirrored workout session from iPhone")
                }
            } catch {
                print("WorkoutSessionManager: Failed to begin collection for mirrored session: \(error)")
            }
        }
    }

    /// Starts a timer to periodically send metrics back to the iPhone
    private func startMetricsSendTimer() {
        metricsSendTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.sendMetricsToPhone()
        }
    }

    /// Stops the metrics send timer
    private func stopMetricsSendTimer() {
        metricsSendTimer?.invalidate()
        metricsSendTimer = nil
    }

    /// Sends current workout metrics to the paired iPhone
    private func sendMetricsToPhone() {
        guard isMirroredSession, let session = session else { return }

        let metrics = WorkoutMetricsData(
            distance: distance,
            stepCount: stepCount,
            activeCalories: activeCalories,
            heartRate: heartRate,
            averageHeartRate: averageHeartRate,
            currentPace: currentPace
        )

        if let data = try? JSONEncoder().encode(metrics) {
            session.sendToRemoteWorkoutSession(data: data) { success, error in
                if let error = error {
                    print("WorkoutSessionManager: Failed to send metrics to phone: \(error)")
                }
            }
        }
    }
    #endif

    #if os(watchOS)
    public func startWorkout(type: WorkoutType, environment: WorkoutEnvironment) async throws {
        guard !isSessionActive else {
            throw WorkoutSessionError.sessionAlreadyActive
        }

        let activityType: HKWorkoutActivityType = type == .walking ? .walking : .running
        let locationType: HKWorkoutSessionLocationType = environment == .outdoor ? .outdoor : .indoor

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = locationType

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session?.delegate = self
            builder?.delegate = self

            let startDate = Date()
            session?.startActivity(with: startDate)
            try await builder?.beginCollection(at: startDate)

            isSessionActive = true
            currentWorkoutType = type
            currentWorkoutEnvironment = environment
            sessionStartDate = startDate

            resetMetrics()
            startUpdateTimer()
        } catch {
            throw WorkoutSessionError.failedToStart(error)
        }
    }

    public func pauseWorkout() {
        session?.pause()
    }

    public func resumeWorkout() {
        session?.resume()
    }

    public func endWorkout() async throws -> HKWorkout? {
        guard isSessionActive else {
            throw WorkoutSessionError.noActiveSession
        }

        session?.end()
        stopUpdateTimer()

        do {
            try await builder?.endCollection(at: Date())

            if let builder = builder {
                let workout = try await builder.finishWorkout()
                cleanup()
                return workout
            }
        } catch {
            cleanup()
            throw WorkoutSessionError.failedToEnd(error)
        }

        cleanup()
        return nil
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
        averagePace = 0
        cadence = 0
        heartRateSamples = []
        isPaused = false
        pausedTime = 0
        lastPauseDate = nil
    }

    private func cleanup() {
        #if os(watchOS)
        session = nil
        builder = nil
        stopMetricsSendTimer()
        isMirroredSession = false
        #endif
        isSessionActive = false
        isPaused = false
        currentWorkoutType = nil
        currentWorkoutEnvironment = nil
        sessionStartDate = nil
        pausedTime = 0
        lastPauseDate = nil
    }

    private func startUpdateTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateElapsedTime()
                }
            }
            RunLoop.main.add(self!.updateTimer!, forMode: .common)
        }
    }

    private func stopUpdateTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTimer?.invalidate()
            self?.updateTimer = nil
        }
    }

    private func updateElapsedTime() {
        guard let startDate = sessionStartDate, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startDate) - pausedTime
    }

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

#if os(watchOS)
extension WorkoutSessionManager: HKWorkoutSessionDelegate {
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
                self.isSessionActive = true
                if fromState == .paused {
                    // Resuming from pause - calculate total paused time
                    if let pauseDate = self.lastPauseDate {
                        self.pausedTime += date.timeIntervalSince(pauseDate)
                    }
                    self.lastPauseDate = nil
                    self.isPaused = false
                    self.startUpdateTimer()
                }
            case .paused:
                self.isPaused = true
                self.lastPauseDate = date
                self.stopUpdateTimer()
            case .ended:
                self.isSessionActive = false
                self.isPaused = false
                self.stopUpdateTimer()
            default:
                break
            }
        }
    }

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.cleanup()
        }
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }

    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            let statistics = workoutBuilder.statistics(for: quantityType)

            // Capture values first, then update on main thread
            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                if let value = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.heartRate = value
                        self.heartRateSamples.append(value)
                        self.averageHeartRate = self.heartRateSamples.reduce(0, +) / Double(self.heartRateSamples.count)
                    }
                }

            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                if let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.distance = value
                        if self.elapsedTime > 0 {
                            let speedMetersPerSecond = value / self.elapsedTime
                            if speedMetersPerSecond > 0 {
                                self.currentPace = 1609.34 / speedMetersPerSecond
                                self.averagePace = self.currentPace
                            }
                        }
                    }
                }

            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                if let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) {
                    DispatchQueue.main.async { [weak self] in
                        self?.activeCalories = value
                    }
                }

            case HKQuantityType.quantityType(forIdentifier: .stepCount):
                if let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.stepCount = Int(value)
                        if self.elapsedTime > 0 {
                            self.cadence = (Double(self.stepCount) / self.elapsedTime) * 60
                        }
                    }
                }

            default:
                break
            }
        }
    }
}
#endif

public enum WorkoutSessionError: LocalizedError {
    case sessionAlreadyActive
    case noActiveSession
    case failedToStart(Error)
    case failedToEnd(Error)

    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "A workout session is already active"
        case .noActiveSession:
            return "No active workout session"
        case .failedToStart(let error):
            return "Failed to start workout: \(error.localizedDescription)"
        case .failedToEnd(let error):
            return "Failed to end workout: \(error.localizedDescription)"
        }
    }
}
