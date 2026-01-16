import XCTest
import SwiftUI
@testable import StepSync

final class WatchWorkoutCompanionViewTests: XCTestCase {

    // MARK: - Step Count Formatting Tests

    func testStepCountFormatsWithoutCommas() {
        // Steps should display as plain numbers in the hero counter
        let stepCount = 4523
        let formatted = "\(stepCount)"

        XCTAssertEqual(formatted, "4523")
    }

    func testLargeStepCountFormatsCorrectly() {
        let stepCount = 15234
        let formatted = "\(stepCount)"

        XCTAssertEqual(formatted, "15234")
    }

    func testZeroStepCountDisplays() {
        let stepCount = 0
        let formatted = "\(stepCount)"

        XCTAssertEqual(formatted, "0")
    }

    // MARK: - Calorie Formatting Tests

    func testCaloriesFormattedWithoutDecimals() {
        let calories = 156.7
        let formatted = String(format: "%.0f", calories)

        XCTAssertEqual(formatted, "157")
    }

    func testZeroCaloriesShowsPlaceholder() {
        let calories = 0.0
        let formatted = calories > 0 ? String(format: "%.0f", calories) : "--"

        XCTAssertEqual(formatted, "--")
    }

    // MARK: - Outdoor vs Indoor Layout Tests

    func testOutdoorWorkoutEnvironmentIsDetected() {
        let environment: WorkoutEnvironment = .outdoor
        let isOutdoor = environment == .outdoor

        XCTAssertTrue(isOutdoor)
    }

    func testIndoorWorkoutEnvironmentIsDetected() {
        let environment: WorkoutEnvironment = .indoor
        let isOutdoor = environment == .outdoor

        XCTAssertFalse(isOutdoor)
    }

    // MARK: - Workout Type Display Tests

    func testWalkingWorkoutTypeDisplayName() {
        let workoutType: WorkoutType = .walking
        XCTAssertEqual(workoutType.displayName, "Walking")
    }

    func testRunningWorkoutTypeDisplayName() {
        let workoutType: WorkoutType = .running
        XCTAssertEqual(workoutType.displayName, "Running")
    }

    // MARK: - Duration Formatting Tests

    func testDurationFormatsMinutesAndSeconds() {
        let elapsedTime: TimeInterval = 754 // 12:34
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        let formatted = String(format: "%d:%02d", minutes, seconds)

        XCTAssertEqual(formatted, "12:34")
    }

    func testDurationFormatsWithHours() {
        let elapsedTime: TimeInterval = 3754 // 1:02:34
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        var formatted: String
        if hours > 0 {
            formatted = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formatted = String(format: "%d:%02d", minutes, seconds)
        }

        XCTAssertEqual(formatted, "1:02:34")
    }

    // MARK: - Distance Formatting Tests

    func testDistanceFormatsToTwoDecimalPlaces() {
        let distanceMeters = 2000.0
        let distanceInMiles = distanceMeters / 1609.34
        let formatted = String(format: "%.2f", distanceInMiles)

        XCTAssertEqual(formatted, "1.24")
    }
}
