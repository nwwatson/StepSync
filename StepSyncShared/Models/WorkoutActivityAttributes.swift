import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// ActivityKit attributes for workout Live Activities.
/// Defines the static and dynamic content displayed during workouts.
#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct WorkoutActivityAttributes: ActivityAttributes {

    /// Static content that doesn't change during the workout
    public struct ContentState: Codable, Hashable, Sendable {
        /// Current step count during this workout
        public var stepCount: Int

        /// Total daily steps (including workout)
        public var totalDailySteps: Int

        /// Current heart rate in BPM
        public var heartRate: Int

        /// Distance in miles
        public var distanceMiles: Double

        /// Elapsed workout time in seconds
        public var elapsedSeconds: Int

        /// Whether the workout is paused
        public var isPaused: Bool

        public init(
            stepCount: Int = 0,
            totalDailySteps: Int = 0,
            heartRate: Int = 0,
            distanceMiles: Double = 0.0,
            elapsedSeconds: Int = 0,
            isPaused: Bool = false
        ) {
            self.stepCount = stepCount
            self.totalDailySteps = totalDailySteps
            self.heartRate = heartRate
            self.distanceMiles = distanceMiles
            self.elapsedSeconds = elapsedSeconds
            self.isPaused = isPaused
        }

        /// Progress toward daily goal (0.0 to 1.0+)
        public func progressTowardGoal(dailyGoal: Int) -> Double {
            guard dailyGoal > 0 else { return 0 }
            return Double(totalDailySteps) / Double(dailyGoal)
        }

        /// Formatted elapsed time (MM:SS or H:MM:SS)
        public var formattedElapsedTime: String {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            let seconds = elapsedSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%d:%02d", minutes, seconds)
        }

        /// Formatted distance string
        public var formattedDistance: String {
            String(format: "%.2f mi", distanceMiles)
        }

        /// Formatted heart rate string
        public var formattedHeartRate: String {
            heartRate > 0 ? "\(heartRate)" : "--"
        }
    }

    /// Type of workout being performed
    public let workoutType: String

    /// SF Symbol name for the workout type
    public let workoutIcon: String

    /// Daily step goal
    public let dailyGoal: Int

    /// When the workout started
    public let workoutStartTime: Date

    public init(
        workoutType: String,
        workoutIcon: String,
        dailyGoal: Int,
        workoutStartTime: Date = Date()
    ) {
        self.workoutType = workoutType
        self.workoutIcon = workoutIcon
        self.dailyGoal = dailyGoal
        self.workoutStartTime = workoutStartTime
    }
}
#endif

// MARK: - UserDefaults Keys for Live Activity Communication

public extension String {
    /// Key for signaling pause/resume from Live Activity
    static let workoutPauseRequestedKey = "workoutPauseRequested"

    /// Key for signaling stop from Live Activity
    static let workoutStopRequestedKey = "workoutStopRequested"

    /// Notification name for pause/resume from Live Activity
    static let togglePauseWorkoutNotification = "TogglePauseWorkoutNotification"

    /// Notification name for stop from Live Activity
    static let stopWorkoutNotification = "StopWorkoutNotification"
}
