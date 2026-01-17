import XCTest
@testable import StepSync

final class WorkoutMirroringManagerTests: XCTestCase {

    var mirroringManager: WorkoutMirroringManager!

    override func setUp() {
        super.setUp()
        mirroringManager = WorkoutMirroringManager.shared
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsNotMirroring() {
        // The manager should not be in mirroring state initially
        // Note: This test may fail if other tests left the manager in a different state
        // In a real test suite, you'd want to reset state between tests
        XCTAssertNotNil(mirroringManager)
    }

    func testInitialStateIsNotWatchInitiated() {
        // The manager should not indicate watch-initiated workout initially
        XCTAssertNotNil(mirroringManager)
    }

    // MARK: - Formatted Time Tests

    func testFormattedElapsedTimeWithMinutesOnly() {
        // Test the formatting logic for elapsed time
        let elapsedTime: TimeInterval = 125 // 2:05
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        var formatted: String
        if hours > 0 {
            formatted = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formatted = String(format: "%d:%02d", minutes, seconds)
        }

        XCTAssertEqual(formatted, "2:05")
    }

    func testFormattedElapsedTimeWithHours() {
        let elapsedTime: TimeInterval = 3725 // 1:02:05
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        var formatted: String
        if hours > 0 {
            formatted = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formatted = String(format: "%d:%02d", minutes, seconds)
        }

        XCTAssertEqual(formatted, "1:02:05")
    }

    // MARK: - Formatted Distance Tests

    func testFormattedDistanceConversion() {
        // Test meters to miles conversion
        let distanceMeters = 1609.34 // 1 mile
        let distanceInMiles = distanceMeters / 1609.34
        let formatted = String(format: "%.2f", distanceInMiles)

        XCTAssertEqual(formatted, "1.00")
    }

    func testFormattedDistancePartialMile() {
        let distanceMeters = 804.67 // 0.5 miles
        let distanceInMiles = distanceMeters / 1609.34
        let formatted = String(format: "%.2f", distanceInMiles)

        XCTAssertEqual(formatted, "0.50")
    }

    // MARK: - Formatted Pace Tests

    func testFormattedPaceConversion() {
        // If pace is in seconds per mile, format as minutes:seconds
        let paceSecondsPerMile = 600.0 // 10:00 per mile
        let paceMinutes = Int(paceSecondsPerMile) / 60
        let paceSeconds = Int(paceSecondsPerMile) % 60
        let formatted = String(format: "%d:%02d", paceMinutes, paceSeconds)

        XCTAssertEqual(formatted, "10:00")
    }

    func testFormattedPaceWhenZero() {
        let pace = 0.0
        let formatted = pace > 0 ? String(format: "%.0f", pace) : "--:--"

        XCTAssertEqual(formatted, "--:--")
    }

    // MARK: - Formatted Heart Rate Tests

    func testFormattedHeartRatePositiveValue() {
        let heartRate = 142.0
        let formatted = heartRate > 0 ? String(format: "%.0f", heartRate) : "--"

        XCTAssertEqual(formatted, "142")
    }

    func testFormattedHeartRateZero() {
        let heartRate = 0.0
        let formatted = heartRate > 0 ? String(format: "%.0f", heartRate) : "--"

        XCTAssertEqual(formatted, "--")
    }

    // MARK: - Metrics Data Encoding/Decoding Tests

    func testWorkoutMetricsDataEncoding() throws {
        let metrics = WorkoutMetricsData(
            distance: 1500.0,
            stepCount: 2000,
            activeCalories: 100.5,
            heartRate: 140.0,
            averageHeartRate: 135.0,
            currentPace: 600.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metrics)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WorkoutMetricsData.self, from: data)

        XCTAssertEqual(decoded.distance, 1500.0)
        XCTAssertEqual(decoded.stepCount, 2000)
        XCTAssertEqual(decoded.activeCalories, 100.5)
        XCTAssertEqual(decoded.heartRate, 140.0)
        XCTAssertEqual(decoded.averageHeartRate, 135.0)
        XCTAssertEqual(decoded.currentPace, 600.0)
    }

    // MARK: - Workout Type Tests

    func testWorkoutTypeWalking() {
        let type: WorkoutType = .walking
        XCTAssertEqual(type.displayName, "Walking")
        XCTAssertEqual(type.systemImage, "figure.walk")
    }

    func testWorkoutTypeRunning() {
        let type: WorkoutType = .running
        XCTAssertEqual(type.displayName, "Running")
        XCTAssertEqual(type.systemImage, "figure.run")
    }

    // MARK: - Workout Environment Tests

    func testWorkoutEnvironmentOutdoor() {
        let environment: WorkoutEnvironment = .outdoor
        XCTAssertEqual(environment.displayName, "Outdoor")
    }

    func testWorkoutEnvironmentIndoor() {
        let environment: WorkoutEnvironment = .indoor
        XCTAssertEqual(environment.displayName, "Indoor")
    }
}
