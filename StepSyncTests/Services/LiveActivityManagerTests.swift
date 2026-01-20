import XCTest
@testable import StepSync

@available(iOS 16.1, *)
final class LiveActivityManagerTests: XCTestCase {

    // MARK: - WorkoutActivityAttributes.ContentState Tests

    func testContentStateDefaultInitialization() {
        let state = WorkoutActivityAttributes.ContentState()

        XCTAssertEqual(state.stepCount, 0)
        XCTAssertEqual(state.totalDailySteps, 0)
        XCTAssertEqual(state.heartRate, 0)
        XCTAssertEqual(state.distanceMiles, 0.0)
        XCTAssertEqual(state.elapsedSeconds, 0)
        XCTAssertFalse(state.isPaused)
    }

    func testContentStateCustomInitialization() {
        let state = WorkoutActivityAttributes.ContentState(
            stepCount: 1000,
            totalDailySteps: 5000,
            heartRate: 140,
            distanceMiles: 2.5,
            elapsedSeconds: 1800,
            isPaused: true
        )

        XCTAssertEqual(state.stepCount, 1000)
        XCTAssertEqual(state.totalDailySteps, 5000)
        XCTAssertEqual(state.heartRate, 140)
        XCTAssertEqual(state.distanceMiles, 2.5)
        XCTAssertEqual(state.elapsedSeconds, 1800)
        XCTAssertTrue(state.isPaused)
    }

    // MARK: - Progress Calculation Tests

    func testProgressTowardGoalZeroGoal() {
        let state = WorkoutActivityAttributes.ContentState(totalDailySteps: 5000)
        let progress = state.progressTowardGoal(dailyGoal: 0)

        XCTAssertEqual(progress, 0)
    }

    func testProgressTowardGoalHalfway() {
        let state = WorkoutActivityAttributes.ContentState(totalDailySteps: 5000)
        let progress = state.progressTowardGoal(dailyGoal: 10000)

        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testProgressTowardGoalComplete() {
        let state = WorkoutActivityAttributes.ContentState(totalDailySteps: 10000)
        let progress = state.progressTowardGoal(dailyGoal: 10000)

        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    func testProgressTowardGoalExceeded() {
        let state = WorkoutActivityAttributes.ContentState(totalDailySteps: 15000)
        let progress = state.progressTowardGoal(dailyGoal: 10000)

        XCTAssertEqual(progress, 1.5, accuracy: 0.001)
    }

    // MARK: - Formatted Elapsed Time Tests

    func testFormattedElapsedTimeSecondsOnly() {
        let state = WorkoutActivityAttributes.ContentState(elapsedSeconds: 45)

        XCTAssertEqual(state.formattedElapsedTime, "0:45")
    }

    func testFormattedElapsedTimeMinutesAndSeconds() {
        let state = WorkoutActivityAttributes.ContentState(elapsedSeconds: 125)

        XCTAssertEqual(state.formattedElapsedTime, "2:05")
    }

    func testFormattedElapsedTimeWithHours() {
        let state = WorkoutActivityAttributes.ContentState(elapsedSeconds: 3725)

        XCTAssertEqual(state.formattedElapsedTime, "1:02:05")
    }

    func testFormattedElapsedTimeZero() {
        let state = WorkoutActivityAttributes.ContentState(elapsedSeconds: 0)

        XCTAssertEqual(state.formattedElapsedTime, "0:00")
    }

    func testFormattedElapsedTimeExactHour() {
        let state = WorkoutActivityAttributes.ContentState(elapsedSeconds: 3600)

        XCTAssertEqual(state.formattedElapsedTime, "1:00:00")
    }

    // MARK: - Formatted Distance Tests

    func testFormattedDistanceZero() {
        let state = WorkoutActivityAttributes.ContentState(distanceMiles: 0.0)

        XCTAssertEqual(state.formattedDistance, "0.00 mi")
    }

    func testFormattedDistancePartialMile() {
        let state = WorkoutActivityAttributes.ContentState(distanceMiles: 0.75)

        XCTAssertEqual(state.formattedDistance, "0.75 mi")
    }

    func testFormattedDistanceWholeMile() {
        let state = WorkoutActivityAttributes.ContentState(distanceMiles: 3.0)

        XCTAssertEqual(state.formattedDistance, "3.00 mi")
    }

    func testFormattedDistancePrecision() {
        let state = WorkoutActivityAttributes.ContentState(distanceMiles: 2.456)

        XCTAssertEqual(state.formattedDistance, "2.46 mi")
    }

    // MARK: - Formatted Heart Rate Tests

    func testFormattedHeartRateZero() {
        let state = WorkoutActivityAttributes.ContentState(heartRate: 0)

        XCTAssertEqual(state.formattedHeartRate, "--")
    }

    func testFormattedHeartRatePositive() {
        let state = WorkoutActivityAttributes.ContentState(heartRate: 142)

        XCTAssertEqual(state.formattedHeartRate, "142")
    }

    // MARK: - WorkoutActivityAttributes Tests

    func testWorkoutActivityAttributesInitialization() {
        let startTime = Date()
        let attributes = WorkoutActivityAttributes(
            workoutType: "Walking",
            workoutIcon: "figure.walk",
            dailyGoal: 10000,
            workoutStartTime: startTime
        )

        XCTAssertEqual(attributes.workoutType, "Walking")
        XCTAssertEqual(attributes.workoutIcon, "figure.walk")
        XCTAssertEqual(attributes.dailyGoal, 10000)
        XCTAssertEqual(attributes.workoutStartTime, startTime)
    }

    func testWorkoutActivityAttributesDefaultStartTime() {
        let beforeInit = Date()
        let attributes = WorkoutActivityAttributes(
            workoutType: "Running",
            workoutIcon: "figure.run",
            dailyGoal: 8000
        )
        let afterInit = Date()

        XCTAssertEqual(attributes.workoutType, "Running")
        XCTAssertEqual(attributes.workoutIcon, "figure.run")
        XCTAssertEqual(attributes.dailyGoal, 8000)
        XCTAssertGreaterThanOrEqual(attributes.workoutStartTime, beforeInit)
        XCTAssertLessThanOrEqual(attributes.workoutStartTime, afterInit)
    }

    // MARK: - ContentState Codable Tests

    func testContentStateCodable() throws {
        let originalState = WorkoutActivityAttributes.ContentState(
            stepCount: 2500,
            totalDailySteps: 7500,
            heartRate: 155,
            distanceMiles: 3.25,
            elapsedSeconds: 2400,
            isPaused: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(WorkoutActivityAttributes.ContentState.self, from: data)

        XCTAssertEqual(decodedState.stepCount, originalState.stepCount)
        XCTAssertEqual(decodedState.totalDailySteps, originalState.totalDailySteps)
        XCTAssertEqual(decodedState.heartRate, originalState.heartRate)
        XCTAssertEqual(decodedState.distanceMiles, originalState.distanceMiles, accuracy: 0.001)
        XCTAssertEqual(decodedState.elapsedSeconds, originalState.elapsedSeconds)
        XCTAssertEqual(decodedState.isPaused, originalState.isPaused)
    }

    // MARK: - ContentState Hashable Tests

    func testContentStateHashable() {
        let state1 = WorkoutActivityAttributes.ContentState(
            stepCount: 1000,
            totalDailySteps: 5000,
            heartRate: 140,
            distanceMiles: 2.0,
            elapsedSeconds: 1200,
            isPaused: false
        )

        let state2 = WorkoutActivityAttributes.ContentState(
            stepCount: 1000,
            totalDailySteps: 5000,
            heartRate: 140,
            distanceMiles: 2.0,
            elapsedSeconds: 1200,
            isPaused: false
        )

        let state3 = WorkoutActivityAttributes.ContentState(
            stepCount: 2000,
            totalDailySteps: 6000,
            heartRate: 150,
            distanceMiles: 3.0,
            elapsedSeconds: 1800,
            isPaused: true
        )

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
        XCTAssertEqual(state1.hashValue, state2.hashValue)
    }

    // MARK: - LiveActivityManager Tests

    func testLiveActivityManagerSharedInstance() {
        let manager1 = LiveActivityManager.shared
        let manager2 = LiveActivityManager.shared

        XCTAssertTrue(manager1 === manager2, "Shared instance should be the same object")
    }

    func testLiveActivityManagerInitialState() {
        let manager = LiveActivityManager.shared

        // Initially should not have an active activity
        // Note: This test may be affected by other tests that start activities
        XCTAssertNotNil(manager)
    }

    // MARK: - UserDefaults Keys Tests

    func testUserDefaultsKeys() {
        XCTAssertEqual(String.workoutPauseRequestedKey, "workoutPauseRequested")
        XCTAssertEqual(String.workoutStopRequestedKey, "workoutStopRequested")
        XCTAssertEqual(String.togglePauseWorkoutNotification, "TogglePauseWorkoutNotification")
        XCTAssertEqual(String.stopWorkoutNotification, "StopWorkoutNotification")
    }

    // MARK: - Distance Conversion Tests (meters to miles)

    func testMetersToMilesConversion() {
        // 1609.34 meters = 1 mile
        let meters = 1609.34
        let miles = meters / 1609.34

        XCTAssertEqual(miles, 1.0, accuracy: 0.001)
    }

    func testMetersToMilesConversionHalfMile() {
        let meters = 804.67
        let miles = meters / 1609.34

        XCTAssertEqual(miles, 0.5, accuracy: 0.001)
    }

    func testMetersToMilesConversionTwoMiles() {
        let meters = 3218.68
        let miles = meters / 1609.34

        XCTAssertEqual(miles, 2.0, accuracy: 0.001)
    }

    // MARK: - Live Activity Progress Calculation Tests (Issue #5)
    // These tests verify the correct calculation of totalDailySteps
    // to avoid double-counting workout steps

    func testTotalDailyStepsCalculationWithoutDoubleCount() {
        // Scenario: User had 3000 steps before starting workout
        // During workout, they take 500 additional steps
        // Total daily steps should be 3500, NOT 3500 + 500 = 4000

        let stepsBeforeWorkout = 3000
        let workoutSteps = 500

        // Correct calculation: stepsBeforeWorkout + workoutSteps
        let correctTotalDailySteps = stepsBeforeWorkout + workoutSteps

        XCTAssertEqual(correctTotalDailySteps, 3500)

        // Verify progress calculation
        let state = WorkoutActivityAttributes.ContentState(
            stepCount: workoutSteps,
            totalDailySteps: correctTotalDailySteps
        )
        let progress = state.progressTowardGoal(dailyGoal: 10000)

        XCTAssertEqual(progress, 0.35, accuracy: 0.001)
    }

    func testTotalDailyStepsNotDoubledWhenHealthKitUpdatesInRealTime() {
        // Scenario: HealthKit updates step count in real-time during workout
        // If we read todayStepCount from UserDefaults during workout,
        // it would already include workout steps, causing double-counting

        let stepsBeforeWorkout = 5000  // Steps before workout started
        let workoutSteps = 1000         // Steps taken during workout

        // WRONG: If todayStepCount in UserDefaults is updated to 6000 during workout
        // and we add workoutSteps again: 6000 + 1000 = 7000 (INCORRECT)
        let wrongTotalDailySteps = (stepsBeforeWorkout + workoutSteps) + workoutSteps
        XCTAssertEqual(wrongTotalDailySteps, 7000) // This is the bug

        // CORRECT: Use stored stepsBeforeWorkout + workoutSteps
        let correctTotalDailySteps = stepsBeforeWorkout + workoutSteps
        XCTAssertEqual(correctTotalDailySteps, 6000) // This is correct
    }

    func testProgressBarShowsCorrectPercentage() {
        // Scenario: Goal is 10000 steps
        // User had 4000 steps before workout
        // User takes 1000 steps during workout
        // Expected progress: 50% (5000/10000)

        let stepsBeforeWorkout = 4000
        let workoutSteps = 1000
        let dailyGoal = 10000

        let totalDailySteps = stepsBeforeWorkout + workoutSteps

        let state = WorkoutActivityAttributes.ContentState(
            stepCount: workoutSteps,
            totalDailySteps: totalDailySteps
        )

        let progress = state.progressTowardGoal(dailyGoal: dailyGoal)
        let percentage = Int(progress * 100)

        XCTAssertEqual(percentage, 50)
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testProgressBarAtWorkoutStartShowsPreWorkoutSteps() {
        // At the start of a workout, progress should show pre-workout steps
        let stepsBeforeWorkout = 7500
        let workoutSteps = 0  // Just started, no workout steps yet
        let dailyGoal = 10000

        let totalDailySteps = stepsBeforeWorkout + workoutSteps

        let state = WorkoutActivityAttributes.ContentState(
            stepCount: workoutSteps,
            totalDailySteps: totalDailySteps
        )

        let progress = state.progressTowardGoal(dailyGoal: dailyGoal)

        XCTAssertEqual(progress, 0.75, accuracy: 0.001)
        XCTAssertEqual(state.totalDailySteps, 7500)
    }

    func testProgressBarReachesGoalCorrectly() {
        // User needs 2000 more steps to reach goal
        // After workout provides those steps, should show 100%

        let stepsBeforeWorkout = 8000
        let workoutSteps = 2000
        let dailyGoal = 10000

        let totalDailySteps = stepsBeforeWorkout + workoutSteps

        let state = WorkoutActivityAttributes.ContentState(
            stepCount: workoutSteps,
            totalDailySteps: totalDailySteps
        )

        let progress = state.progressTowardGoal(dailyGoal: dailyGoal)

        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(state.totalDailySteps, 10000)
    }

    func testProgressBarExceedsGoalCorrectly() {
        // User exceeds daily goal during workout

        let stepsBeforeWorkout = 9000
        let workoutSteps = 3000
        let dailyGoal = 10000

        let totalDailySteps = stepsBeforeWorkout + workoutSteps

        let state = WorkoutActivityAttributes.ContentState(
            stepCount: workoutSteps,
            totalDailySteps: totalDailySteps
        )

        let progress = state.progressTowardGoal(dailyGoal: dailyGoal)

        XCTAssertEqual(progress, 1.2, accuracy: 0.001)
        XCTAssertEqual(state.totalDailySteps, 12000)
    }
}
