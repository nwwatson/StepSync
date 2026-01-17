import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Manages Live Activity lifecycle for workout tracking.
/// Shows real-time workout metrics on the lock screen and Dynamic Island.
#if os(iOS)
@available(iOS 16.1, *)
@Observable
public final class LiveActivityManager: @unchecked Sendable {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private let appGroupID = "group.com.nwwsolutions.steppingszn"

    private init() {}

    /// Whether Live Activities are supported on this device
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Whether a workout Live Activity is currently active
    public var hasActiveActivity: Bool {
        currentActivity != nil
    }

    /// Starts a new workout Live Activity
    /// - Parameters:
    ///   - workoutType: Display name of the workout type (e.g., "Walking")
    ///   - workoutIcon: SF Symbol name for the workout
    ///   - dailyGoal: Daily step goal
    ///   - initialSteps: Initial workout step count
    ///   - initialDailySteps: Total daily steps at workout start
    /// - Returns: Whether the activity was successfully started
    @discardableResult
    public func startWorkoutActivity(
        workoutType: String,
        workoutIcon: String,
        dailyGoal: Int,
        initialSteps: Int = 0,
        initialDailySteps: Int = 0
    ) -> Bool {
        guard areActivitiesEnabled else {
            print("LiveActivityManager: Live Activities not enabled")
            return false
        }

        // End any existing activity first
        if currentActivity != nil {
            endWorkoutActivity()
        }

        let attributes = WorkoutActivityAttributes(
            workoutType: workoutType,
            workoutIcon: workoutIcon,
            dailyGoal: dailyGoal,
            workoutStartTime: Date()
        )

        let initialState = WorkoutActivityAttributes.ContentState(
            stepCount: initialSteps,
            totalDailySteps: initialDailySteps,
            heartRate: 0,
            distanceMiles: 0.0,
            elapsedSeconds: 0,
            isPaused: false
        )

        let content = ActivityContent(
            state: initialState,
            staleDate: nil,
            relevanceScore: 100
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            print("LiveActivityManager: Started workout Live Activity")
            return true
        } catch {
            print("LiveActivityManager: Failed to start Live Activity: \(error)")
            return false
        }
    }

    /// Updates the workout Live Activity with new metrics
    /// - Parameters:
    ///   - stepCount: Current workout step count
    ///   - totalDailySteps: Total daily steps including workout
    ///   - heartRate: Current heart rate in BPM
    ///   - distanceMeters: Distance traveled in meters
    ///   - elapsedSeconds: Elapsed workout time in seconds
    ///   - isPaused: Whether the workout is paused
    public func updateWorkoutActivity(
        stepCount: Int,
        totalDailySteps: Int,
        heartRate: Int,
        distanceMeters: Double,
        elapsedSeconds: Int,
        isPaused: Bool
    ) {
        guard let activity = currentActivity else {
            print("LiveActivityManager: No active workout activity to update")
            return
        }

        let distanceMiles = distanceMeters / 1609.34

        let updatedState = WorkoutActivityAttributes.ContentState(
            stepCount: stepCount,
            totalDailySteps: totalDailySteps,
            heartRate: heartRate,
            distanceMiles: distanceMiles,
            elapsedSeconds: elapsedSeconds,
            isPaused: isPaused
        )

        let content = ActivityContent(
            state: updatedState,
            staleDate: nil,
            relevanceScore: 100
        )

        Task {
            await activity.update(content)
        }
    }

    /// Ends the workout Live Activity
    /// - Parameters:
    ///   - finalStepCount: Final workout step count
    ///   - finalTotalDailySteps: Final total daily steps
    ///   - finalHeartRate: Final heart rate
    ///   - finalDistanceMeters: Final distance in meters
    ///   - finalElapsedSeconds: Final elapsed time
    public func endWorkoutActivity(
        finalStepCount: Int? = nil,
        finalTotalDailySteps: Int? = nil,
        finalHeartRate: Int? = nil,
        finalDistanceMeters: Double? = nil,
        finalElapsedSeconds: Int? = nil
    ) {
        guard let activity = currentActivity else {
            print("LiveActivityManager: No active workout activity to end")
            return
        }

        var finalState: WorkoutActivityAttributes.ContentState?

        if let stepCount = finalStepCount,
           let totalDailySteps = finalTotalDailySteps {
            let distanceMiles = (finalDistanceMeters ?? 0) / 1609.34
            finalState = WorkoutActivityAttributes.ContentState(
                stepCount: stepCount,
                totalDailySteps: totalDailySteps,
                heartRate: finalHeartRate ?? 0,
                distanceMiles: distanceMiles,
                elapsedSeconds: finalElapsedSeconds ?? 0,
                isPaused: false
            )
        }

        Task {
            if let state = finalState {
                let content = ActivityContent(
                    state: state,
                    staleDate: nil,
                    relevanceScore: 0
                )
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        currentActivity = nil
        print("LiveActivityManager: Ended workout Live Activity")
    }

    /// Ends all workout Live Activities (cleanup)
    public func endAllActivities() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}
#endif
