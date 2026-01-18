import XCTest
import SwiftData
@testable import StepSync

final class WorkoutTests: XCTestCase {

    // MARK: - Workout Initialization Tests

    func testWorkoutInitialization() {
        let workout = Workout(type: .walking, environment: .outdoor)

        XCTAssertEqual(workout.workoutType, .walking)
        XCTAssertEqual(workout.environment, .outdoor)
        XCTAssertFalse(workout.isCompleted)
        XCTAssertEqual(workout.duration, 0)
        XCTAssertEqual(workout.distance, 0)
        XCTAssertEqual(workout.stepCount, 0)
        XCTAssertNotNil(workout.id)
    }

    func testWorkoutInitializationWithRunning() {
        let workout = Workout(type: .running, environment: .indoor)

        XCTAssertEqual(workout.workoutType, .running)
        XCTAssertEqual(workout.environment, .indoor)
    }

    // MARK: - Workout Complete Tests

    func testCompleteSetIsCompletedTrue() {
        let workout = Workout(type: .walking, environment: .outdoor)
        XCTAssertFalse(workout.isCompleted)

        workout.complete()

        XCTAssertTrue(workout.isCompleted)
        XCTAssertNotNil(workout.endDate)
    }

    func testCompleteCalculatesDurationWhenPreserveDurationIsFalse() {
        let startDate = Date()
        let workout = Workout(type: .walking, environment: .outdoor, startDate: startDate)
        workout.duration = 0

        // Wait a tiny bit to have some elapsed time
        let endDate = startDate.addingTimeInterval(300) // 5 minutes later

        workout.complete(endDate: endDate, preserveDuration: false)

        // Duration should be calculated from startDate to endDate
        XCTAssertEqual(workout.duration, 300, accuracy: 0.1)
        XCTAssertTrue(workout.isCompleted)
    }

    func testCompletePreservesDurationWhenPreserveDurationIsTrue() {
        let startDate = Date()
        let workout = Workout(type: .walking, environment: .outdoor, startDate: startDate)

        // Set duration from HealthKit (simulated)
        let healthKitDuration: TimeInterval = 250 // 4 min 10 sec (accounts for pauses)
        workout.duration = healthKitDuration

        // Complete with endDate 5 minutes after start, but preserve the HealthKit duration
        let endDate = startDate.addingTimeInterval(300) // 5 minutes later
        workout.complete(endDate: endDate, preserveDuration: true)

        // Duration should be preserved (not overwritten to 300)
        XCTAssertEqual(workout.duration, healthKitDuration, accuracy: 0.1)
        XCTAssertTrue(workout.isCompleted)
        XCTAssertEqual(workout.endDate, endDate)
    }

    func testCompleteCalculatesDurationWhenDurationIsZeroEvenWithPreserveFlag() {
        let startDate = Date()
        let workout = Workout(type: .walking, environment: .outdoor, startDate: startDate)
        workout.duration = 0 // Duration not set

        let endDate = startDate.addingTimeInterval(180) // 3 minutes later
        workout.complete(endDate: endDate, preserveDuration: true)

        // Duration should be calculated because it was 0
        XCTAssertEqual(workout.duration, 180, accuracy: 0.1)
        XCTAssertTrue(workout.isCompleted)
    }

    func testCompleteUpdatesUpdatedAt() {
        let workout = Workout(type: .walking, environment: .outdoor)
        let originalUpdatedAt = workout.updatedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        workout.complete()

        XCTAssertGreaterThan(workout.updatedAt, originalUpdatedAt)
    }

    // MARK: - Workout Metrics Tests

    func testWorkoutMetricsAssignment() {
        let workout = Workout(type: .running, environment: .outdoor)

        workout.duration = 1800 // 30 minutes
        workout.distance = 5000 // 5 km
        workout.stepCount = 6000
        workout.activeCalories = 350.5
        workout.averageHeartRate = 145.0
        workout.averagePace = 360.0 // 6 min/km
        workout.averageCadence = 170.0

        XCTAssertEqual(workout.duration, 1800)
        XCTAssertEqual(workout.distance, 5000)
        XCTAssertEqual(workout.stepCount, 6000)
        XCTAssertEqual(workout.activeCalories, 350.5)
        XCTAssertEqual(workout.averageHeartRate, 145.0)
        XCTAssertEqual(workout.averagePace, 360.0)
        XCTAssertEqual(workout.averageCadence, 170.0)
    }

    // MARK: - Formatted Output Tests

    func testFormattedDurationMinutesOnly() {
        let workout = Workout(type: .walking, environment: .outdoor)
        workout.duration = 185 // 3:05

        XCTAssertEqual(workout.formattedDuration, "3:05")
    }

    func testFormattedDurationWithHours() {
        let workout = Workout(type: .walking, environment: .outdoor)
        workout.duration = 3725 // 1:02:05

        XCTAssertEqual(workout.formattedDuration, "1:02:05")
    }

    func testFormattedDistanceInMiles() {
        let workout = Workout(type: .running, environment: .outdoor)
        workout.distance = 1609.34 // 1 mile in meters

        XCTAssertEqual(workout.formattedDistance, "1.00 mi")
    }

    func testFormattedDistancePartialMile() {
        let workout = Workout(type: .running, environment: .outdoor)
        workout.distance = 4023.35 // 2.5 miles in meters

        XCTAssertEqual(workout.formattedDistance, "2.50 mi")
    }

    func testFormattedPace() {
        let workout = Workout(type: .running, environment: .outdoor)
        workout.averagePace = 600 // 10 minutes per mile in seconds

        XCTAssertEqual(workout.formattedPace, "10'00\"/mi")
    }

    func testFormattedPaceNilWhenZero() {
        let workout = Workout(type: .running, environment: .outdoor)
        workout.averagePace = 0

        XCTAssertNil(workout.formattedPace)
    }

    func testFormattedPaceNilWhenNotSet() {
        let workout = Workout(type: .running, environment: .outdoor)

        XCTAssertNil(workout.formattedPace)
    }

    // MARK: - Workout Type Enum Tests

    func testWorkoutTypeRawValueRoundTrip() {
        let workout = Workout(type: .running, environment: .outdoor)

        XCTAssertEqual(workout.workoutTypeRaw, "running")
        XCTAssertEqual(workout.workoutType, .running)

        workout.workoutType = .walking
        XCTAssertEqual(workout.workoutTypeRaw, "walking")
    }

    func testWorkoutEnvironmentRawValueRoundTrip() {
        let workout = Workout(type: .walking, environment: .indoor)

        XCTAssertEqual(workout.environmentRaw, "indoor")
        XCTAssertEqual(workout.environment, .indoor)

        workout.environment = .outdoor
        XCTAssertEqual(workout.environmentRaw, "outdoor")
    }

    // MARK: - Weekly Metrics Calculation Tests

    func testWeeklyMetricsCalculation() {
        // Create test workouts
        let now = Date()
        let calendar = Calendar.current

        var workouts: [Workout] = []

        // Workout from 2 days ago (should be included)
        let workout1 = Workout(
            type: .walking,
            environment: .outdoor,
            startDate: calendar.date(byAdding: .day, value: -2, to: now)!
        )
        workout1.duration = 1800 // 30 minutes
        workout1.distance = 3000 // 3 km
        workout1.isCompleted = true
        workouts.append(workout1)

        // Workout from 5 days ago (should be included)
        let workout2 = Workout(
            type: .running,
            environment: .outdoor,
            startDate: calendar.date(byAdding: .day, value: -5, to: now)!
        )
        workout2.duration = 2400 // 40 minutes
        workout2.distance = 6000 // 6 km
        workout2.isCompleted = true
        workouts.append(workout2)

        // Workout from 10 days ago (should NOT be included)
        let workout3 = Workout(
            type: .walking,
            environment: .indoor,
            startDate: calendar.date(byAdding: .day, value: -10, to: now)!
        )
        workout3.duration = 900
        workout3.distance = 1500
        workout3.isCompleted = true
        workouts.append(workout3)

        // Calculate this week's metrics
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let thisWeekWorkouts = workouts.filter { $0.isCompleted && $0.startDate >= weekAgo }

        let totalDuration = thisWeekWorkouts.reduce(0) { $0 + $1.duration }
        let totalDistance = thisWeekWorkouts.reduce(0) { $0 + $1.distance }

        XCTAssertEqual(thisWeekWorkouts.count, 2)
        XCTAssertEqual(totalDuration, 4200) // 30 + 40 = 70 minutes = 4200 seconds
        XCTAssertEqual(totalDistance, 9000) // 3 + 6 = 9 km
    }

    func testWeeklyMetricsExcludesIncompleteWorkouts() {
        let now = Date()
        let calendar = Calendar.current

        var workouts: [Workout] = []

        // Completed workout
        let workout1 = Workout(
            type: .walking,
            environment: .outdoor,
            startDate: calendar.date(byAdding: .day, value: -1, to: now)!
        )
        workout1.duration = 1800
        workout1.distance = 3000
        workout1.isCompleted = true
        workouts.append(workout1)

        // Incomplete workout (should be excluded)
        let workout2 = Workout(
            type: .running,
            environment: .outdoor,
            startDate: calendar.date(byAdding: .day, value: -2, to: now)!
        )
        workout2.duration = 2400
        workout2.distance = 6000
        workout2.isCompleted = false // NOT completed
        workouts.append(workout2)

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let thisWeekWorkouts = workouts.filter { $0.isCompleted && $0.startDate >= weekAgo }

        XCTAssertEqual(thisWeekWorkouts.count, 1)
        XCTAssertEqual(thisWeekWorkouts.first?.duration, 1800)
    }

    // MARK: - HealthKit ID Tests

    func testHealthKitWorkoutIDAssignment() {
        let workout = Workout(type: .walking, environment: .outdoor)
        XCTAssertNil(workout.healthKitWorkoutID)

        let hkID = UUID()
        workout.healthKitWorkoutID = hkID

        XCTAssertEqual(workout.healthKitWorkoutID, hkID)
    }
}
